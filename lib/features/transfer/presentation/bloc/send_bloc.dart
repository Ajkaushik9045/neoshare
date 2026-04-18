import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/platform/transfer_api.g.dart';
import '../../../../core/platform/foreground_service_bridge.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/crypto_util.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../domain/entities/recipient.dart';
import '../../domain/entities/transfer_file.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/repositories/transfer_repo.dart';

part 'send_event.dart';
part 'send_state.dart';

/// BLoC responsible for send transfer interactions.
/// File selection is handled exclusively via Pigeon [FileHostApi.pickFiles()].
class SendBloc extends Bloc<SendEvent, SendState> {
  SendBloc(this._transferRepo, this._bridge) : super(const SendIdle()) {
    on<LookupRecipient>(_onLookupRecipient);
    on<FilesChosen>(_onFilesChosen);
    on<UploadConfirmed>(_onUploadConfirmed);
    on<UploadProgressUpdated>(_onUploadProgressUpdated);
    on<UploadFinished>(_onUploadFinished);
    on<UploadErrored>(_onUploadErrored);
  }

  final TransferRepo _transferRepo;
  final ForegroundServiceBridge _bridge;
  final Uuid _uuid = const Uuid();

  Recipient? _resolvedRecipient;
  String? _resolvedCode;
  String? _transferId;
  List<PickedFileInfo> _selectedFiles = [];
  Map<String, double> _fileProgressMap = {};

  Future<void> _onLookupRecipient(
    LookupRecipient event,
    Emitter<SendState> emit,
  ) async {
    final cleanCode = ShortCodeUtil.normalize(event.recipientShortCode);
    final senderClean = ShortCodeUtil.normalize(event.senderShortCode);

    emit(const LookingUpRecipient());
    try {
      final recipient = await _transferRepo.validateRecipientCode(
        senderShortCode: senderClean,
        recipientShortCode: cleanCode,
      );
      _resolvedRecipient = recipient;
      _resolvedCode = cleanCode;
      emit(RecipientFound(cleanCode, recipient.uid));
    } catch (error) {
      emit(RecipientNotFound(_friendlyMessage(error)));
    }
  }

  Future<void> _onFilesChosen(
    FilesChosen event,
    Emitter<SendState> emit,
  ) async {
    emit(const PreparingUpload());

    AppLogger.step('Pigeon pickFiles returned ${event.files.length} file(s)');

    const maxBytes = 500 * 1024 * 1024;
    for (final file in event.files) {
      AppLogger.step('Pigeon file: ${file.name} | ${file.sizeBytes} bytes | ${file.mimeType}');
      if (file.sizeBytes > maxBytes) {
        emit(const UploadFailed('One or more files exceed the 500 MB limit.'));
        return;
      }
    }

    _selectedFiles = event.files;

    final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
    final isMetered = connectivityResult.contains(ConnectivityResult.mobile);

    final totalBytes = event.files.fold<int>(0, (acc, f) => acc + f.sizeBytes);
    final isLarge = totalBytes > 10 * 1024 * 1024;
    final shouldWarn = isMetered && isLarge;

    emit(FilesSelected(event.files, isMetered: shouldWarn));
    if (!shouldWarn) {
      add(const UploadConfirmed());
    }
  }

  Future<void> _onUploadConfirmed(
    UploadConfirmed event,
    Emitter<SendState> emit,
  ) async {
    if (_resolvedRecipient == null || _selectedFiles.isEmpty || _resolvedCode == null) return;

    _transferId = _uuid.v4();
    _fileProgressMap = {for (final f in _selectedFiles) f.name: 0.0};
    emit(Uploading(fileProgress: Map.from(_fileProgressMap), totalProgress: 0.0));

    try {
      await _bridge.startUpload(_transferId!);
      final tFiles = <TransferFile>[];
      final fileIdMap = <String, String>{};

      for (final pickedFile in _selectedFiles) {
        final fId = _uuid.v4();
        fileIdMap[pickedFile.name] = fId;

        final localFile = File(pickedFile.path);
        AppLogger.step('Computing SHA-256 for ${pickedFile.name} via Pigeon-staged path');
        final sha256 = await CryptoUtil.computeFileSha256(localFile);

        tFiles.add(TransferFile(
          fileId: fId,
          name: pickedFile.name,
          sizeBytes: pickedFile.sizeBytes,
          mimeType: pickedFile.mimeType,
          storagePath: 'transfers/$_transferId/$fId',
          sha256: sha256,
          status: FileStatus.downloading,
          bytesUploaded: 0,
        ));
      }

      AppLogger.step('Creating Firestore transfer document $_transferId');
      await _transferRepo.createPendingTransfer(
        transferId: _transferId!,
        senderId: 'temp-sender-id',
        senderCode: 'temp-sender',
        recipientCode: _resolvedCode!,
        recipientUid: _resolvedRecipient!.uid,
        files: tFiles,
      );

      await _transferRepo.updateTransferStatus(_transferId!, TransferStatus.transferring);
      AppLogger.step('Upload started for ${_selectedFiles.length} file(s) — all via Pigeon-picked paths');

      final uploadFutures = <Future<void>>[];
      for (final pickedFile in _selectedFiles) {
        final tFile = tFiles.firstWhere((x) => x.fileId == fileIdMap[pickedFile.name]);
        uploadFutures.add(_uploadOneFile(pickedFile, tFile));
      }

      await Future.wait(uploadFutures);
      await _transferRepo.updateTransferStatus(_transferId!, TransferStatus.complete);
      AppLogger.success('All files uploaded for transfer $_transferId');
      await _bridge.stopUpload();
      add(const UploadFinished());
    } catch (e) {
      AppLogger.error('Upload failed for transfer $_transferId', data: e.toString());
      if (_transferId != null) {
        await _transferRepo.updateTransferStatus(_transferId!, TransferStatus.failed);
      }
      await _bridge.stopUpload();
      add(UploadErrored('Transfer failed: $e'));
    }
  }

  Future<void> _uploadOneFile(PickedFileInfo pickedFile, TransferFile tFile) async {
    final localFile = File(pickedFile.path);
    double latestProgress = 0.0;
    bool success = false;
    int retries = 0;

    AppLogger.step('Uploading ${pickedFile.name} from Pigeon path: ${pickedFile.path}');

    while (!success) {
      try {
        await for (final progress in _transferRepo.uploadFile(tFile, localFile, _transferId!)) {
          latestProgress = progress;
          add(UploadProgressUpdated(fileId: pickedFile.name, progress: progress));
        }
        success = true;
      } catch (e) {
        final err = e.toString().toLowerCase();
        final isTransient = err.contains('network') ||
            err.contains('terminated') ||
            err.contains('canceled') ||
            err.contains('unknown') ||
            err.contains('timeout') ||
            err.contains('-13000') ||
            err.contains('-13040');

        if (isTransient && retries < 300) {
          retries++;
          AppLogger.warning('Upload retry $retries for ${pickedFile.name}', data: err);
          await Future.delayed(const Duration(seconds: 5));
        } else {
          await _transferRepo.updateFileProgress(
              _transferId!, tFile.fileId, (tFile.sizeBytes * latestProgress).toInt(), null, FileStatus.failed);
          throw Exception('File upload failed: ${pickedFile.name} — $e');
        }
      }
    }

    await _transferRepo.updateFileProgress(
        _transferId!, tFile.fileId, tFile.sizeBytes, null, FileStatus.complete);
    add(UploadProgressUpdated(fileId: pickedFile.name, progress: 1.0));
    AppLogger.success('Uploaded ${pickedFile.name} (${tFile.sizeBytes} bytes)');
  }

  void _onUploadProgressUpdated(UploadProgressUpdated event, Emitter<SendState> emit) {
    if (state is! Uploading) return;
    _fileProgressMap[event.fileId] = event.progress;
    double total = 0;
    _fileProgressMap.forEach((_, v) => total += v);
    total = total / _fileProgressMap.length;

    _bridge.updateProgress((total * 100).round());
    emit(Uploading(fileProgress: Map.from(_fileProgressMap), totalProgress: total));
  }

  void _onUploadFinished(UploadFinished event, Emitter<SendState> emit) => emit(const UploadComplete());

  void _onUploadErrored(UploadErrored event, Emitter<SendState> emit) => emit(UploadFailed(event.reason));

  String _friendlyMessage(Object error) {
    final raw = error.toString();
    final stripped = raw.replaceFirst('Exception: ', '').replaceFirst('FirebaseException: ', '').trim();
    return stripped.isEmpty || stripped == 'null'
        ? 'Something went wrong while validating recipient. Please try again.'
        : stripped;
  }
}

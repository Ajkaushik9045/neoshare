import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/crypto_util.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../domain/entities/recipient.dart';
import '../../domain/entities/transfer_file.dart';
import '../../domain/repositories/transfer_repo.dart';

part 'send_event.dart';
part 'send_state.dart';

/// BLoC responsible for send transfer interactions.
class SendBloc extends Bloc<SendEvent, SendState> {
  SendBloc(this._transferRepo) : super(const SendIdle()) {
    on<LookupRecipient>(_onLookupRecipient);
    on<FilesChosen>(_onFilesChosen);
    on<UploadConfirmed>(_onUploadConfirmed);
    on<UploadProgressUpdated>(_onUploadProgressUpdated);
    on<UploadFinished>(_onUploadFinished);
    on<UploadErrored>(_onUploadErrored);
  }

  final TransferRepo _transferRepo;
  final Uuid _uuid = const Uuid();

  Recipient? _resolvedRecipient;
  String? _resolvedCode;
  String? _transferId;
  List<PlatformFile> _selectedFiles = [];
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

    const maxBytes = 500 * 1024 * 1024;
    for (var file in event.files) {
      if (file.size > maxBytes) {
        emit(const UploadFailed('One or more files exceed the 500 MB limit.'));
        return;
      }
    }

    _selectedFiles = event.files;
    
    final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
    final isMetered = connectivityResult.contains(ConnectivityResult.mobile);
    
    int totalBytes = 0;
    for (var f in event.files) totalBytes += f.size;
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
    _fileProgressMap = { for (var f in _selectedFiles) (f.identifier ?? f.name): 0.0 };
    emit(Uploading(fileProgress: Map.from(_fileProgressMap), totalProgress: 0.0));

    try {
      final tFiles = <TransferFile>[];
      final fileIds = <String, String>{};
      
      for (var pFile in _selectedFiles) {
        final fId = _uuid.v4();
        fileIds[pFile.identifier ?? pFile.name] = fId;
        
        final localFile = File(pFile.path!);
        final sha256 = await CryptoUtil.computeFileSha256(localFile);
        
        tFiles.add(TransferFile(
          fileId: fId,
          name: pFile.name,
          sizeBytes: pFile.size,
          mimeType: pFile.extension != null ? 'application/${pFile.extension}' : 'application/octet-stream',
          storagePath: 'transfers/$_transferId/$fId',
          sha256: sha256,
          status: 'uploading',
          bytesUploaded: 0,
        ));
      }

      await _transferRepo.createPendingTransfer(
        transferId: _transferId!,
        senderId: 'temp-sender-id', // TODO: user id from auth bloc
        recipientCode: _resolvedCode!,
        recipientUid: _resolvedRecipient!.uid,
        files: tFiles,
      );

      await _transferRepo.updateTransferStatus(_transferId!, 'transferring');

      final uploadFutures = <Future<void>>[];
      for (var pFile in _selectedFiles) {
        final key = pFile.identifier ?? pFile.name;
        final tFile = tFiles.firstWhere((x) => x.fileId == fileIds[key]);
        final future = _uploadOneFile(pFile, tFile, key);
        uploadFutures.add(future);
      }

      await Future.wait(uploadFutures);
      await _transferRepo.updateTransferStatus(_transferId!, 'complete');
      add(const UploadFinished());

    } catch (e) {
      if (_transferId != null) {
        await _transferRepo.updateTransferStatus(_transferId!, 'failed');
      }
      add(UploadErrored('Transfer failed: $e'));
    }
  }

  Future<void> _uploadOneFile(PlatformFile pFile, TransferFile tFile, String progressKey) async {
    final localFile = File(pFile.path!);
    double latestProgress = 0.0;
    bool success = false;
    int retries = 0;
    
    while (!success) {
      try {
        await for (final progress in _transferRepo.uploadFile(tFile, localFile, _transferId!)) {
          latestProgress = progress;
          add(UploadProgressUpdated(fileId: progressKey, progress: progress));
        }
        success = true;
      } catch (e) {
        final err = e.toString().toLowerCase();
        final isNetworkDrop = err.contains('network') || 
                              err.contains('terminated') || 
                              err.contains('canceled') || 
                              err.contains('unknown') || 
                              err.contains('timeout') ||
                              err.contains('-13000') || 
                              err.contains('-13040');

        if (isNetworkDrop) {
          if (retries >= 300) { // ~25 mins of continuous offline attempts
            await _transferRepo.updateFileProgress(_transferId!, tFile.fileId, (tFile.sizeBytes * latestProgress).toInt(), 'failed');
            throw Exception('Network timeout exceeded for file upload: $e');
          }
          retries++;
          await Future.delayed(const Duration(seconds: 5));
        } else {
          await _transferRepo.updateFileProgress(_transferId!, tFile.fileId, (tFile.sizeBytes * latestProgress).toInt(), 'failed');
          throw Exception('File upload failed fatally: $e');
        }
      }
    }
    
    // Complete
    await _transferRepo.updateFileProgress(_transferId!, tFile.fileId, tFile.sizeBytes, 'complete');
    add(UploadProgressUpdated(fileId: progressKey, progress: 1.0));
  }

  void _onUploadProgressUpdated(UploadProgressUpdated event, Emitter<SendState> emit) {
    if (state is! Uploading) return;
    _fileProgressMap[event.fileId] = event.progress;
    double total = 0;
    _fileProgressMap.forEach((k, v) => total += v);
    total = total / _fileProgressMap.length;
    
    emit(Uploading(fileProgress: Map.from(_fileProgressMap), totalProgress: total));
  }

  void _onUploadFinished(UploadFinished event, Emitter<SendState> emit) {
    emit(const UploadComplete());
  }

  void _onUploadErrored(UploadErrored event, Emitter<SendState> emit) {
    emit(UploadFailed(event.reason));
  }

  String _friendlyMessage(Object error) {
    final raw = error.toString();
    final stripped = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('FirebaseException: ', '')
        .trim();
    if (stripped.isEmpty || stripped == 'null') {
      return 'Something went wrong while validating recipient. Please try again.';
    }
    return stripped;
  }
}

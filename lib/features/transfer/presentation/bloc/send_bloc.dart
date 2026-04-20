import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/platform/transfer_api.g.dart';
import '../../../../core/platform/foreground_service_bridge.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/crypto_util.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../data/datasources/local_transfer_ds.dart';
import '../../../identity/data/datasources/local_identity_ds.dart';
import '../../domain/entities/recipient.dart';
import '../../domain/entities/transfer_file.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/repositories/transfer_repo.dart';

part 'send_event.dart';
part 'send_state.dart';

/// BLoC responsible for send transfer interactions.
/// File selection is handled exclusively via Pigeon [FileHostApi.pickFiles()].
class SendBloc extends Bloc<SendEvent, SendState> {
  SendBloc(this._transferRepo, this._bridge, this._localDs, this._identityDs)
    : super(const SendIdle()) {
    on<LookupRecipient>(_onLookupRecipient);
    on<FilesChosen>(_onFilesChosen);
    on<UploadConfirmed>(_onUploadConfirmed);
    on<UploadProgressUpdated>(_onUploadProgressUpdated);
    on<UploadFinished>(_onUploadFinished);
    on<UploadErrored>(_onUploadErrored);
    on<AppResumed>(_onAppResumed);
    on<SendReset>((_, emit) => emit(const SendIdle()));

    // Listen for app resume signal from Android MainActivity
    if (Platform.isAndroid) {
      const MethodChannel(
        'com.example.neoshare/app_lifecycle',
      ).setMethodCallHandler((call) async {
        if (call.method == 'onAppResumed') {
          add(const AppResumed());
        }
      });
    }
  }

  final TransferRepo _transferRepo;
  final ForegroundServiceBridge _bridge;
  final LocalTransferDataSource _localDs;
  final LocalIdentityDataSource _identityDs;
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
    final validated = <PickedFileInfo>[];

    for (final file in event.files) {
      AppLogger.step(
        'Pigeon file: ${file.name} | ${file.sizeBytes} bytes | ${file.mimeType}',
      );

      // Reject zero-byte files — nothing to upload
      if (file.sizeBytes == 0) {
        AppLogger.warning('Skipping zero-byte file: ${file.name}');
        emit(UploadFailed('"${file.name}" is empty and cannot be sent.'));
        return;
      }

      if (file.sizeBytes > maxBytes) {
        emit(const UploadFailed('One or more files exceed the 500 MB limit.'));
        return;
      }

      // Resolve MIME: prefer system value, fall back to mime package,
      // then octet-stream for extensionless/unknown files.
      final resolvedMime = _resolveMimeType(file.mimeType, file.name);
      AppLogger.step('MIME resolved: ${file.name} → $resolvedMime');

      validated.add(
        PickedFileInfo(
          path: file.path,
          name: file.name,
          sizeBytes: file.sizeBytes,
          mimeType: resolvedMime,
        ),
      );
    }

    _selectedFiles = validated;

    final List<ConnectivityResult> connectivityResult = await Connectivity()
        .checkConnectivity();
    final isMetered = connectivityResult.contains(ConnectivityResult.mobile);

    final totalBytes = validated.fold<int>(0, (acc, f) => acc + f.sizeBytes);
    final isLarge = totalBytes > 10 * 1024 * 1024;
    final shouldWarn = isMetered && isLarge;

    emit(FilesSelected(validated, isMetered: shouldWarn));
    if (!shouldWarn) {
      add(const UploadConfirmed());
    }
  }

  Future<void> _onUploadConfirmed(
    UploadConfirmed event,
    Emitter<SendState> emit,
  ) async {
    if (_resolvedRecipient == null ||
        _selectedFiles.isEmpty ||
        _resolvedCode == null) {
      return;
    }

    _transferId = _uuid.v4();
    _fileProgressMap = {for (final f in _selectedFiles) f.name: 0.0};
    emit(
      Uploading(fileProgress: Map.from(_fileProgressMap), totalProgress: 0.0),
    );

    try {
      await _bridge.startUpload(_transferId!);
      // Persist so we can recover if the process is killed
      await _localDs.saveActiveTransferId(_transferId!);
      final tFiles = <TransferFile>[];
      final fileIdMap = <String, String>{};

      for (final pickedFile in _selectedFiles) {
        final fId = _uuid.v4();
        fileIdMap[pickedFile.name] = fId;

        final localFile = File(pickedFile.path);
        AppLogger.step(
          'Computing SHA-256 for ${pickedFile.name} via Pigeon-staged path',
        );
        final sha256 = await CryptoUtil.computeFileSha256(localFile);

        tFiles.add(
          TransferFile(
            fileId: fId,
            name: pickedFile.name,
            sizeBytes: pickedFile.sizeBytes,
            mimeType: pickedFile.mimeType,
            storagePath: 'transfers/$_transferId/$fId',
            sha256: sha256,
            status: FileStatus.downloading,
            bytesUploaded: 0,
          ),
        );
      }

      AppLogger.step('Creating Firestore transfer document $_transferId');
      final sender = _identityDs.getCachedUser();
      await _transferRepo.createPendingTransfer(
        transferId: _transferId!,
        senderId: sender?.uid ?? '',
        senderCode: sender?.shortCode ?? '',
        recipientCode: _resolvedCode!,
        recipientUid: _resolvedRecipient!.uid,
        files: tFiles,
      );

      await _transferRepo.updateTransferStatus(
        _transferId!,
        TransferStatus.transferring,
      );
      AppLogger.step(
        'Upload started for ${_selectedFiles.length} file(s) — all via Pigeon-picked paths',
      );

      // Run all uploads concurrently. Each file handles its own retries and
      // marks itself failed independently — one failure does not cancel others.
      final results = await Future.wait(
        _selectedFiles.map((pickedFile) {
          final tFile = tFiles.firstWhere(
            (x) => x.fileId == fileIdMap[pickedFile.name],
          );
          return _uploadOneFile(
            pickedFile,
            tFile,
          ).then<Object?>((_) => null).onError<Object>((e, _) {
            AppLogger.error(
              'File upload failed (isolated): ${pickedFile.name}',
              data: e.toString(),
            );
            return e;
          });
        }),
      );

      final failures = results.whereType<Object>().toList();
      final successCount = results.length - failures.length;

      AppLogger.step(
        'Upload batch done: $successCount/${results.length} succeeded',
      );

      if (failures.isEmpty) {
        // All files uploaded successfully
        await _transferRepo.updateTransferStatus(
          _transferId!,
          TransferStatus.complete,
        );
        AppLogger.success('All files uploaded for transfer $_transferId');
        await _bridge.stopUpload();
        await _localDs.clearActiveTransferId();
        add(const UploadFinished());
      } else if (successCount == 0) {
        // Every file failed — treat as full failure
        throw Exception('All file uploads failed.');
      } else {
        // Partial success — some files uploaded, some failed
        await _transferRepo.updateTransferStatus(
          _transferId!,
          TransferStatus.complete,
        );
        AppLogger.warning(
          'Partial upload: $successCount/${results.length} files succeeded',
        );
        await _bridge.stopUpload();
        await _localDs.clearActiveTransferId();
        add(const UploadFinished());
      }
    } catch (e) {
      AppLogger.error(
        'Upload failed for transfer $_transferId',
        data: e.toString(),
      );
      if (_transferId != null) {
        await _transferRepo.updateTransferStatus(
          _transferId!,
          TransferStatus.failed,
        );
      }
      await _bridge.stopUpload();
      await _localDs.clearActiveTransferId();
      add(UploadErrored(_friendlyUploadError(e)));
    }
  }

  Future<void> _uploadOneFile(
    PickedFileInfo pickedFile,
    TransferFile tFile,
  ) async {
    final localFile = File(pickedFile.path);
    double latestProgress = 0.0;
    bool success = false;
    int retries = 0;

    AppLogger.step(
      'Uploading ${pickedFile.name} from Pigeon path: ${pickedFile.path}',
    );

    while (!success) {
      try {
        await for (final progress in _transferRepo.uploadFile(
          tFile,
          localFile,
          _transferId!,
        )) {
          latestProgress = progress;
          add(
            UploadProgressUpdated(fileId: pickedFile.name, progress: progress),
          );
        }
        success = true;
      } catch (e) {
        final err = e.toString().toLowerCase();
        final isTransient =
            err.contains('network') ||
            err.contains('terminated') ||
            err.contains('canceled') ||
            err.contains('unknown') ||
            err.contains('timeout') ||
            err.contains('-13000') ||
            err.contains('-13040');

        if (isTransient && retries < 300) {
          retries++;
          AppLogger.warning(
            'Upload retry $retries for ${pickedFile.name}',
            data: err,
          );
          await Future.delayed(const Duration(seconds: 5));
        } else {
          await _transferRepo.updateFileProgress(
            _transferId!,
            tFile.fileId,
            (tFile.sizeBytes * latestProgress).toInt(),
            null,
            FileStatus.failed,
          );
          throw Exception('File upload failed: ${pickedFile.name} — $e');
        }
      }
    }

    await _transferRepo.updateFileProgress(
      _transferId!,
      tFile.fileId,
      tFile.sizeBytes,
      null,
      FileStatus.complete,
    );
    add(UploadProgressUpdated(fileId: pickedFile.name, progress: 1.0));
    AppLogger.success('Uploaded ${pickedFile.name} (${tFile.sizeBytes} bytes)');
  }

  void _onUploadProgressUpdated(
    UploadProgressUpdated event,
    Emitter<SendState> emit,
  ) {
    if (state is! Uploading) return;
    _fileProgressMap[event.fileId] = event.progress;
    double total = 0;
    _fileProgressMap.forEach((_, v) => total += v);
    total = total / _fileProgressMap.length;

    _bridge.updateProgress((total * 100).round());
    emit(
      Uploading(fileProgress: Map.from(_fileProgressMap), totalProgress: total),
    );
  }

  void _onUploadFinished(UploadFinished event, Emitter<SendState> emit) =>
      emit(const UploadComplete());

  void _onUploadErrored(UploadErrored event, Emitter<SendState> emit) =>
      emit(UploadFailed(event.reason));

  /// When the app resumes, check if there's an in-progress transfer in Firestore.
  /// If so, transition to UploadPaused so the UI can prompt the user to resume.
  Future<void> _onAppResumed(AppResumed event, Emitter<SendState> emit) async {
    if (state is Uploading) return; // already running

    // Recover transferId from Hive if the process was killed
    _transferId ??= _localDs.getActiveTransferId();

    if (_transferId == null) {
      AppLogger.step(
        'AppResumed — no active transfer found, nothing to resume',
      );
      return;
    }

    AppLogger.step('AppResumed — checking transfer status', data: _transferId);
    try {
      final status = await _transferRepo.getTransferStatus(_transferId!);
      if (status == TransferStatus.transferring) {
        AppLogger.step('Transfer still transferring — showing paused UI');
        emit(UploadPaused(transferId: _transferId!));
      } else {
        // Transfer already completed/failed while app was away — clean up
        AppLogger.step('Transfer no longer active ($status) — clearing');
        await _localDs.clearActiveTransferId();
        _transferId = null;
      }
    } catch (e) {
      AppLogger.warning(
        'AppResumed: could not check transfer status',
        data: e.toString(),
      );
    }
  }

  /// Maps upload errors to user-friendly messages.
  /// Detects rate-limit deletions (document not found after creation).
  String _friendlyUploadError(Object error) {
    final raw = error.toString().toLowerCase();
    // When the rate-limit function deletes the transfer doc, subsequent
    // Firestore writes fail with "not-found".
    if (raw.contains('not-found') || raw.contains('no document to update')) {
      return 'You have sent too many transfers recently. Please wait a while before trying again.';
    }
    if (raw.contains('permission-denied')) {
      return 'Transfer was blocked. Please check your connection and try again.';
    }
    return 'Transfer failed. Please try again.';
  }

  /// Resolves the best MIME type for a file.  ///
  /// Priority:
  /// 1. System-provided [mimeType] if specific (not octet-stream or empty).
  /// 2. [lookupMimeType] from the `mime` package — handles .heic, .webp, .mov.
  /// 3. Falls back to `application/octet-stream` for extensionless/unknown.
  String _resolveMimeType(String mimeType, String fileName) {
    if (mimeType.isNotEmpty && mimeType != 'application/octet-stream') {
      return mimeType;
    }
    final looked = lookupMimeType(fileName);
    if (looked != null && looked.isNotEmpty) return looked;
    return 'application/octet-stream';
  }

  String _friendlyMessage(Object error) {
    final raw = error.toString();
    final stripped = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('FirebaseException: ', '')
        .trim();
    return stripped.isEmpty || stripped == 'null'
        ? 'Something went wrong while validating recipient. Please try again.'
        : stripped;
  }
}

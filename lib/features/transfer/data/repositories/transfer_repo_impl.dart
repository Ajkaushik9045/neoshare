import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../domain/entities/recipient.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';
import '../../domain/repositories/transfer_repo.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../datasources/firestore_transfer_ds.dart';
import '../datasources/storage_ds.dart';
import '../datasources/local_transfer_ds.dart';
import '../models/transfer_model.dart';
import '../../../../core/platform/file_api.g.dart';

/// Concrete repository composing storage and Firestore data sources.
class TransferRepoImpl implements TransferRepo {
  TransferRepoImpl({
    required StorageDataSource storageDataSource,
    required FirestoreTransferDataSource firestoreTransferDataSource,
    required LocalTransferDataSource localTransferDataSource,
    required FirebaseFirestore firestore,
  })  : _storageDataSource = storageDataSource,
        _firestoreTransferDataSource = firestoreTransferDataSource,
        _localTransferDataSource = localTransferDataSource,
        _firestore = firestore,
        _fileApi = FileHostApi();

  final StorageDataSource _storageDataSource;
  final FirestoreTransferDataSource _firestoreTransferDataSource;
  final LocalTransferDataSource _localTransferDataSource;
  final FirebaseFirestore _firestore;
  final FileHostApi _fileApi;

  @override
  Future<Recipient> validateRecipientCode({
    required String senderShortCode,
    required String recipientShortCode,
  }) async {
    final normalizedSender = ShortCodeUtil.normalize(senderShortCode);
    final normalizedRecipient = ShortCodeUtil.normalize(recipientShortCode);
    AppLogger.step(
      'Validating recipient code',
      data: 'sender=$normalizedSender, recipient=$normalizedRecipient',
    );

    if (normalizedSender == normalizedRecipient) {
      AppLogger.warning('Self-send blocked', data: normalizedSender);
      throw Exception('You cannot send files to yourself');
    }

    final recipientDoc = await _firestore.collection('users').doc(normalizedRecipient).get();
    if (!recipientDoc.exists) {
      AppLogger.warning('Invalid recipient code entered', data: normalizedRecipient);
      throw Exception('User not found. Please check the short code and try again.');
    }

    final uid = recipientDoc.data()?['uid'] as String?;
    final fcmToken = recipientDoc.data()?['fcmToken'] as String?;
    if (uid == null || uid.isEmpty) {
      AppLogger.error('Recipient doc missing uid', data: normalizedRecipient);
      throw Exception('Recipient data is incomplete. Please try again later.');
    }

    AppLogger.success('Recipient validation passed', data: normalizedRecipient);
    return Recipient(
      uid: uid,
      fcmToken: fcmToken ?? '',
    );
  }

  @override
  Future<Transfer> createPendingTransfer({
    required String transferId,
    required String senderId,
    required String senderCode,
    required String recipientCode,
    required String recipientUid,
    required List<TransferFile> files,
  }) async {
    return _firestoreTransferDataSource.createTransfer(
      transferId: transferId,
      senderId: senderId,
      senderCode: senderCode,
      recipientCode: recipientCode,
      recipientUid: recipientUid,
      files: files,
    );
  }

  @override
  Future<void> updateTransferStatus(String transferId, TransferStatus status) async {
    return _firestoreTransferDataSource.updateTransferStatus(transferId, status);
  }

  @override
  Stream<double> uploadFile(TransferFile fileDesc, File localFile, String transferId) {
    return _storageDataSource.uploadFile(fileDesc, localFile, transferId).map((snapshot) {
      if (snapshot.totalBytes == 0) return 0.0;
      return snapshot.bytesTransferred / snapshot.totalBytes;
    });
  }

  @override
  Future<void> updateFileProgress(
    String transferId,
    String fileId,
    int? bytesUploaded,
    int? bytesDownloaded,
    FileStatus status, {
    String? sha256,
  }) async {
    return _firestoreTransferDataSource.updateFileProgress(
      transferId,
      fileId,
      bytesUploaded,
      bytesDownloaded,
      status,
      sha256: sha256,
    );
  }

  @override
  Stream<List<Transfer>> watchIncoming({required String receiverId}) {
    return _firestoreTransferDataSource.watchIncoming(receiverId: receiverId);
  }

  @override
  Stream<Transfer> downloadTransfer(String transferId, [String? specificFileId]) async* {
    if (specificFileId == null && _localTransferDataSource.isProcessed(transferId)) {
      AppLogger.warning('Transfer $transferId already fully processed, skipping.', data: null);
      return;
    }

    final docRef = _firestore.collection('transfers').doc(transferId);
    final doc = await docRef.get();
    final model = TransferModel.fromDoc(doc);

    final filesToDownload = model.files.where((f) {
      if (specificFileId != null) return f.fileId == specificFileId;
      return true;
    }).toList();

    // ── Storage space check ──────────────────────────────────────────────────
    final totalSize = filesToDownload.fold<int>(0, (acc, f) => acc + f.sizeBytes);
    try {
      final freeSpace = await _fileApi.getFreeSpace();
      if (freeSpace < totalSize) {
        throw Exception(
          'Not enough storage space. '
          'Need ${totalSize ~/ 1024 ~/ 1024} MB but only ${freeSpace ~/ 1024 ~/ 1024} MB available.',
        );
      }
    } catch (e) {
      if (e.toString().contains('Not enough storage')) rethrow;
      // Pigeon channel unavailable on this platform — continue without check.
    }

    // ── Temp directory: always app-writable, Firebase can create files here ──
    // We CANNOT pass user-selected SAF paths directly to Firebase writeToFile()
    // because on Android 10+ those are content URIs / scoped paths.
    final tempDir = Directory.systemTemp.createTempSync('neoshare_dl_');

    for (final fileModel in filesToDownload) {
      // Step 1: Download to temp (unconditionally writable)
      final tempFile = File('${tempDir.path}/${fileModel.fileId}.tmp');

      try {
        await updateFileProgress(transferId, fileModel.fileId, null, 0, FileStatus.downloading);

        final downloadTask = _storageDataSource.storage
            .ref(fileModel.storagePath)
            .writeToFile(tempFile);

        await for (final snapshot in downloadTask.snapshotEvents) {
          if (snapshot.state == TaskState.error) {
            throw Exception('Firebase Storage error: ${fileModel.name}');
          }
        }

        if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
          throw Exception('Downloaded file is empty or missing: ${fileModel.name}');
        }

        // Step 2: Save via Pigeon → MediaStore (Android) / Documents (iOS)
        // This is the ONLY reliable cross-platform way to write to public storage.
        AppLogger.step('Pigeon saveToDownloads() → ${fileModel.name} (${fileModel.mimeType})');
        try {
          final savedPath = await _fileApi.saveToDownloads(
            tempFile.path,
            fileModel.mimeType,
            fileModel.name,
          );
          AppLogger.success('Pigeon saveToDownloads: ${fileModel.name} → $savedPath');
        } catch (pigeonErr) {
          // Non-fatal: file is still in temp, but user may not see it in Downloads.
          AppLogger.warning('Pigeon saveToDownloads failed for ${fileModel.name}', data: pigeonErr.toString());
        }
        await tempFile.delete();

        await updateFileProgress(
            transferId, fileModel.fileId, null, fileModel.sizeBytes, FileStatus.complete);
        AppLogger.success('Download complete: ${fileModel.name}');
      } catch (e) {
        AppLogger.error('Download failed: ${fileModel.name}', data: e.toString());
        await updateFileProgress(transferId, fileModel.fileId, null, 0, FileStatus.failed);
        if (tempFile.existsSync()) await tempFile.delete();
      }
    }

    // Clean up temp dir (any stragglers)
    try { tempDir.deleteSync(recursive: true); } catch (_) {}

    final updatedModel = TransferModel.fromDoc(await docRef.get());

    if (specificFileId == null) {
      await _localTransferDataSource.markProcessed(transferId);
    }

    yield updatedModel;
  }
}

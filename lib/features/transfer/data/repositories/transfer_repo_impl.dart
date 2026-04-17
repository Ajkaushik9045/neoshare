import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../domain/entities/recipient.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';
import '../../domain/repositories/transfer_repo.dart';
import '../datasources/firestore_transfer_ds.dart';
import '../datasources/storage_ds.dart';

/// Concrete repository composing storage and Firestore data sources.
class TransferRepoImpl implements TransferRepo {
  TransferRepoImpl({
    required StorageDataSource storageDataSource,
    required FirestoreTransferDataSource firestoreTransferDataSource,
    required FirebaseFirestore firestore,
  })  : _storageDataSource = storageDataSource,
        _firestoreTransferDataSource = firestoreTransferDataSource,
        _firestore = firestore;

  final StorageDataSource _storageDataSource;
  final FirestoreTransferDataSource _firestoreTransferDataSource;
  final FirebaseFirestore _firestore;

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
    required String recipientCode,
    required String recipientUid,
    required List<TransferFile> files,
  }) async {
    return _firestoreTransferDataSource.createTransfer(
      transferId: transferId,
      senderId: senderId,
      recipientCode: recipientCode,
      recipientUid: recipientUid,
      files: files,
    );
  }

  @override
  Future<void> updateTransferStatus(String transferId, String status) async {
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
    int bytesUploaded,
    String status, {
    String? sha256,
  }) async {
    return _firestoreTransferDataSource.updateFileProgress(
      transferId,
      fileId,
      bytesUploaded,
      status,
      sha256: sha256,
    );
  }

  @override
  Stream<List<Transfer>> watchIncoming({required String receiverId}) {
    return _firestoreTransferDataSource.watchIncoming(receiverId: receiverId);
  }
}

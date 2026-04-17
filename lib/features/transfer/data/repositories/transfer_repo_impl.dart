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
  Future<Transfer> sendTransfer({
    required String receiverId,
    required List<TransferFile> files,
  }) async {
    await _storageDataSource.uploadFiles(files);
    final transferModel = await _firestoreTransferDataSource.createTransfer(
      senderId: 'temp-sender-id',
      receiverId: receiverId,
      files: files
          .map(
            (file) => {
              'name': file.name,
              'sizeBytes': file.sizeBytes,
              'mimeType': file.mimeType,
            },
          )
          .toList(),
    );
    return transferModel;
  }

  @override
  Stream<List<Transfer>> watchIncoming({required String receiverId}) {
    return _firestoreTransferDataSource.watchIncoming(receiverId: receiverId);
  }
}

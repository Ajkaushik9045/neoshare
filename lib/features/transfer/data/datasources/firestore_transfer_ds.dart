import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transfer_model.dart';
import '../../domain/entities/transfer_file.dart';

/// Handles transfer metadata operations in Firestore.
class FirestoreTransferDataSource {
  FirestoreTransferDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Writes transfer metadata to Firestore.
  Future<TransferModel> createTransfer({
    required String transferId,
    required String senderId,
    required String recipientCode,
    required String recipientUid,
    required List<TransferFile> files,
  }) async {
    final docRef = _firestore.collection('transfers').doc(transferId);
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 48));

    final transfer = TransferModel(
      id: transferId,
      senderId: senderId,
      recipientCode: recipientCode,
      recipientUid: recipientUid,
      status: 'pending',
      createdAt: now,
      expiresAt: expiresAt,
      files: files,
    );

    await docRef.set(transfer.toJson());
    return transfer;
  }

  Future<void> updateTransferStatus(String transferId, String status) async {
    await _firestore.collection('transfers').doc(transferId).update({
      'status': status,
    });
  }

  Future<void> updateFileProgress(
    String transferId,
    String fileId,
    int bytesUploaded,
    String status, {
    String? sha256,
  }) async {
    final docRef = _firestore.collection('transfers').doc(transferId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final filesList = List<Map<String, dynamic>>.from(data['files'] ?? []);
      for (int i = 0; i < filesList.length; i++) {
        if (filesList[i]['fileId'] == fileId) {
          filesList[i]['bytesUploaded'] = bytesUploaded;
          filesList[i]['status'] = status;
          if (sha256 != null) {
            filesList[i]['sha256'] = sha256;
          }
          break;
        }
      }

      transaction.update(docRef, {'files': filesList});
    });
  }

  /// Streams incoming transfer metadata for a receiver.
  Stream<List<TransferModel>> watchIncoming({required String receiverId}) {
    return _firestore
        .collection('transfers')
        .where('recipientUid', isEqualTo: receiverId)
        .where('status', isNotEqualTo: 'expired')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransferModel.fromJson(doc.data(), doc.id))
            .toList());
  }
}

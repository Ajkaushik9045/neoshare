import '../models/transfer_model.dart';

/// Handles transfer metadata operations in Firestore.
class FirestoreTransferDataSource {
  /// Writes transfer metadata.
  ///
  /// Placeholder implementation creates an in-memory model.
  Future<TransferModel> createTransfer({
    required String senderId,
    required String receiverId,
    required List<Map<String, dynamic>> files,
  }) async {
    return TransferModel.fromJson(
      {
        'id': 'temp-transfer-id',
        'senderId': senderId,
        'receiverId': receiverId,
        'createdAtIso': DateTime.now().toUtc().toIso8601String(),
        'files': files,
      },
    );
  }

  /// Streams incoming transfer metadata for a receiver.
  Stream<List<TransferModel>> watchIncoming({required String receiverId}) async* {
    yield const <TransferModel>[];
  }
}

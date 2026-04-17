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
  })  : _storageDataSource = storageDataSource,
        _firestoreTransferDataSource = firestoreTransferDataSource;

  final StorageDataSource _storageDataSource;
  final FirestoreTransferDataSource _firestoreTransferDataSource;

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

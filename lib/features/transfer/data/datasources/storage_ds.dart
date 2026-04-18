import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/transfer_file.dart';

/// Handles file upload/download in storage backend.
class StorageDataSource {
  StorageDataSource(this._storage);

  final FirebaseStorage _storage;
  FirebaseStorage get storage => _storage;

  /// Uploads a single file and yields progress.
  Stream<TaskSnapshot> uploadFile(TransferFile fileDesc, File localFile, String transferId) {
    final ref = _storage.ref().child('transfers/$transferId/${fileDesc.fileId}');
    final metadata = SettableMetadata(contentType: fileDesc.mimeType);
    
    final uploadTask = ref.putFile(localFile, metadata);
    return uploadTask.snapshotEvents;
  }
}

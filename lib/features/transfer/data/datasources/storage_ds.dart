import '../../domain/entities/transfer_file.dart';

/// Handles file upload/download in storage backend.
class StorageDataSource {
  /// Uploads transfer files and returns temporary URLs.
  ///
  /// Placeholder values are returned in Phase 1.
  Future<List<String>> uploadFiles(List<TransferFile> files) async {
    return files.map((file) => 'https://placeholder.local/${file.name}').toList();
  }
}

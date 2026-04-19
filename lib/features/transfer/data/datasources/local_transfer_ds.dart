import 'package:hive_flutter/hive_flutter.dart';

/// Local data source to track processed transfer IDs to avoid duplication,
/// and to persist which individual file IDs have been saved to device storage.
class LocalTransferDataSource {
  final Box<dynamic> _box;

  static const String boxName = 'transfer_metadata';
  static const String _processedKey = 'processed_transfers';
  static const String _savedFilesKey = 'saved_file_ids';

  LocalTransferDataSource(this._box);

  // ── Transfer-level (all files saved) ──────────────────────────────────────

  /// Checks if a transfer has already been fully processed.
  bool isProcessed(String transferId) {
    final list =
        _box.get(_processedKey, defaultValue: <String>[]) as List<dynamic>;
    return list.contains(transferId);
  }

  /// Marks a transfer as fully processed.
  Future<void> markProcessed(String transferId) async {
    final list = List<String>.from(
      _box.get(_processedKey, defaultValue: <String>[]) as List<dynamic>,
    );
    if (!list.contains(transferId)) {
      list.add(transferId);
      await _box.put(_processedKey, list);
    }
  }

  // ── File-level (individual file saved) ────────────────────────────────────

  /// Returns all file IDs that have been saved to device storage.
  Set<String> getSavedFileIds() {
    final list =
        _box.get(_savedFilesKey, defaultValue: <String>[]) as List<dynamic>;
    return Set<String>.from(list);
  }

  /// Marks a single file ID as saved to device storage.
  Future<void> markFileSaved(String fileId) async {
    final list = List<String>.from(
      _box.get(_savedFilesKey, defaultValue: <String>[]) as List<dynamic>,
    );
    if (!list.contains(fileId)) {
      list.add(fileId);
      await _box.put(_savedFilesKey, list);
    }
  }

  /// Checks if a specific file has been saved to device storage.
  bool isFileSaved(String fileId) {
    final list =
        _box.get(_savedFilesKey, defaultValue: <String>[]) as List<dynamic>;
    return list.contains(fileId);
  }
}

import 'package:hive_flutter/hive_flutter.dart';

/// Local data source to track processed transfer IDs to avoid duplication.
class LocalTransferDataSource {
  final Box<dynamic> _box;
  
  static const String boxName = 'transfer_metadata';
  static const String _processedKey = 'processed_transfers';

  LocalTransferDataSource(this._box);

  /// Checks if a transfer ID has already been fully processed.
  bool isProcessed(String transferId) {
    final list = _box.get(_processedKey, defaultValue: <String>[]) as List<dynamic>;
    return list.contains(transferId);
  }

  /// Marks a transfer ID as fully processed.
  Future<void> markProcessed(String transferId) async {
    final list = List<String>.from(_box.get(_processedKey, defaultValue: <String>[]) as List<dynamic>);
    if (!list.contains(transferId)) {
      list.add(transferId);
      await _box.put(_processedKey, list);
    }
  }
}

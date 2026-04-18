import 'dart:io';

import 'transfer_api.g.dart';

/// Dart facade over [TransferServiceHostApi].
///
/// All methods are no-ops on non-Android platforms so callers need no
/// platform guards of their own.
class ForegroundServiceBridge {
  ForegroundServiceBridge(this._api);

  final TransferServiceHostApi _api;

  /// Starts the Android [TransferForegroundService] for [transferId].
  Future<void> startUpload(String transferId) async {
    if (!Platform.isAndroid) return;
    await _api.startUploadService(transferId);
  }

  /// Stops the Android [TransferForegroundService].
  Future<void> stopUpload() async {
    if (!Platform.isAndroid) return;
    await _api.stopUploadService();
  }

  /// Updates the persistent notification progress to [percent] (0–100).
  Future<void> updateProgress(int percent) async {
    if (!Platform.isAndroid) return;
    await _api.updateProgress(percent);
  }
}

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../utils/app_logger.dart';

/// Result of a storage permission check.
enum StoragePermissionStatus {
  /// Granted, or not required on this platform/OS version.
  granted,

  /// Denied — user can be asked again.
  denied,

  /// Permanently denied — must open system settings.
  permanentlyDenied,
}

/// Handles storage permissions across Android versions.
///
/// - Android 10+ (API 29+): MediaStore/SAF needs no permission.
///   [Permission.storage.status] returns [PermissionStatus.granted]
///   automatically — no dialog ever shown.
/// - Android ≤ 9 (API ≤ 28): `WRITE_EXTERNAL_STORAGE` required.
/// - iOS / other: not required → granted.
class StoragePermissionService {
  /// Returns current status without prompting.
  Future<StoragePermissionStatus> currentStatus() async {
    if (!Platform.isAndroid) return StoragePermissionStatus.granted;
    return _map(await Permission.storage.status);
  }

  /// Requests storage permission and returns the result.
  ///
  /// On Android 10+, [Permission.storage] is auto-granted by the OS
  /// without showing a dialog. On Android ≤ 9, shows the system dialog.
  Future<StoragePermissionStatus> request() async {
    if (!Platform.isAndroid) return StoragePermissionStatus.granted;

    final status = await Permission.storage.request();
    final result = _map(status);

    AppLogger.step(
      'StoragePermissionService.request()',
      data: 'raw=${status.name} mapped=${result.name}',
    );

    return result;
  }

  StoragePermissionStatus _map(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return StoragePermissionStatus.granted;
      case PermissionStatus.permanentlyDenied:
        return StoragePermissionStatus.permanentlyDenied;
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        return StoragePermissionStatus.denied;
    }
  }
}

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Result of a notification permission request.
enum NotificationPermissionStatus {
  /// Permission is granted (or not required on this platform/OS version).
  granted,

  /// Permission was denied by the user.
  denied,

  /// Permission is permanently denied — user must open system settings.
  permanentlyDenied,
}

/// Handles the Android 13+ `POST_NOTIFICATIONS` runtime permission.
///
/// On platforms other than Android, or on Android < 13 (API 33), the
/// permission is not required and [requestIfNeeded] immediately returns
/// [NotificationPermissionStatus.granted].
class NotificationPermissionService {
  /// The last known permission status, populated after [requestIfNeeded] is called.
  NotificationPermissionStatus lastStatus = NotificationPermissionStatus.granted;

  /// Requests the notification permission if needed and returns the result.
  ///
  /// - Android 13+ (API 33+): delegates to [permission_handler].
  /// - All other platforms / older Android: returns [NotificationPermissionStatus.granted].
  Future<NotificationPermissionStatus> requestIfNeeded() async {
    if (!Platform.isAndroid) {
      lastStatus = NotificationPermissionStatus.granted;
      return lastStatus;
    }

    // permission_handler automatically skips the dialog on Android < 13
    // because POST_NOTIFICATIONS is only a runtime permission from API 33.
    // Requesting it on older versions returns PermissionStatus.granted.
    final status = await Permission.notification.request();
    lastStatus = _map(status);
    return lastStatus;
  }

  /// Returns the current permission status without prompting the user.
  Future<NotificationPermissionStatus> currentStatus() async {
    if (!Platform.isAndroid) {
      return NotificationPermissionStatus.granted;
    }
    final status = await Permission.notification.status;
    return _map(status);
  }

  NotificationPermissionStatus _map(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return NotificationPermissionStatus.granted;
      case PermissionStatus.permanentlyDenied:
        return NotificationPermissionStatus.permanentlyDenied;
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        return NotificationPermissionStatus.denied;
    }
  }
}

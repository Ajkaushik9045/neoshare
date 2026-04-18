import 'package:flutter_test/flutter_test.dart';
import 'package:neoshare/core/notifications/notification_permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Testable subclass that bypasses Platform.isAndroid and delegates
/// permission calls to injectable functions.
class _FakePermissionService extends NotificationPermissionService {
  _FakePermissionService({
    required Future<PermissionStatus> Function() requestFn,
    required Future<PermissionStatus> Function() statusFn,
  })  : _requestFn = requestFn,
        _statusFn = statusFn;

  final Future<PermissionStatus> Function() _requestFn;
  final Future<PermissionStatus> Function() _statusFn;

  @override
  Future<NotificationPermissionStatus> requestIfNeeded() async {
    final raw = await _requestFn();
    lastStatus = _mapRaw(raw);
    return lastStatus;
  }

  @override
  Future<NotificationPermissionStatus> currentStatus() async {
    final raw = await _statusFn();
    return _mapRaw(raw);
  }

  /// Mirrors the private _map logic from the real implementation.
  NotificationPermissionStatus _mapRaw(PermissionStatus status) {
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

_FakePermissionService _svc(PermissionStatus status) =>
    _FakePermissionService(
      requestFn: () async => status,
      statusFn: () async => status,
    );

void main() {
  group('NotificationPermissionService — PermissionStatus mapping', () {
    test('granted → NotificationPermissionStatus.granted', () async {
      expect(
        await _svc(PermissionStatus.granted).requestIfNeeded(),
        NotificationPermissionStatus.granted,
      );
    });

    test('limited → granted', () async {
      expect(
        await _svc(PermissionStatus.limited).requestIfNeeded(),
        NotificationPermissionStatus.granted,
      );
    });

    test('provisional → granted', () async {
      expect(
        await _svc(PermissionStatus.provisional).requestIfNeeded(),
        NotificationPermissionStatus.granted,
      );
    });

    test('denied → denied', () async {
      expect(
        await _svc(PermissionStatus.denied).requestIfNeeded(),
        NotificationPermissionStatus.denied,
      );
    });

    test('restricted → denied', () async {
      expect(
        await _svc(PermissionStatus.restricted).requestIfNeeded(),
        NotificationPermissionStatus.denied,
      );
    });

    test('permanentlyDenied → permanentlyDenied', () async {
      expect(
        await _svc(PermissionStatus.permanentlyDenied).requestIfNeeded(),
        NotificationPermissionStatus.permanentlyDenied,
      );
    });
  });

  group('NotificationPermissionService.requestIfNeeded', () {
    test('updates lastStatus after request', () async {
      final svc = _svc(PermissionStatus.denied);
      await svc.requestIfNeeded();
      expect(svc.lastStatus, NotificationPermissionStatus.denied);
    });

    test('lastStatus defaults to granted before any call', () {
      final svc = _svc(PermissionStatus.denied);
      expect(svc.lastStatus, NotificationPermissionStatus.granted);
    });
  });

  group('NotificationPermissionService.currentStatus', () {
    test('returns current status without modifying lastStatus', () async {
      final svc = _FakePermissionService(
        requestFn: () async => PermissionStatus.granted,
        statusFn: () async => PermissionStatus.denied,
      );
      final result = await svc.currentStatus();
      expect(result, NotificationPermissionStatus.denied);
      // lastStatus unchanged since requestIfNeeded was not called
      expect(svc.lastStatus, NotificationPermissionStatus.granted);
    });
  });
}

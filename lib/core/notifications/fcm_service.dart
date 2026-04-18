import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../utils/app_logger.dart';

// ─── Background handler ────────────────────────────────────────────────────
// Must be top-level. Registered ONCE in main.dart, NOT inside the service.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this runs.
  // No UI work here — the system shows the notification automatically.
  AppLogger.step(
    'FCM background message received',
    data: 'id=${message.messageId} data=${message.data}',
  );
}

// ─── Android notification channel ─────────────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'NeoShare Notifications',
  description: 'Incoming file transfer alerts',
  importance: Importance.max,
  playSound: true,
);

// ─── Local notifications plugin (module-level singleton) ──────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Initialises [flutter_local_notifications] and creates the Android channel.
/// Call once from [FcmService.initialize].
Future<void> initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
  );

  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onLocalNotificationTap,
  );

  // Create the high-importance channel on Android 8+
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_channel);

  AppLogger.step('flutter_local_notifications initialised');
}

// Callback when user taps a local notification (foreground-shown).
// Uses the payload (action string) to route — router injected via closure.
void Function(NotificationResponse)? _onLocalNotificationTap;

/// Production-grade FCM service.
///
/// Responsibilities:
/// - Permission request
/// - Token save + refresh
/// - Foreground notification display via [flutter_local_notifications]
/// - Deep-link routing for all app states
class FcmService {
  FcmService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
    required GoRouter router,
  }) : _messaging = messaging,
       _firestore = firestore,
       _router = router;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final GoRouter _router;
  bool _initialized = false;

  /// Call once after identity is provisioned.
  /// [userShortCode] is the Firestore document ID under `users/`.
  Future<void> initialize(String userShortCode) async {
    // Always update the tap callback so the current router instance is used,
    // but skip re-registering listeners on hot restart.
    _onLocalNotificationTap = (response) {
      final action = response.payload;
      AppLogger.step('Local notification tapped', data: 'payload=$action');
      _route(action);
    };

    if (_initialized) {
      AppLogger.step(
        'FcmService already initialized, skipping re-registration',
      );
      return;
    }
    _initialized = true;

    AppLogger.step('FcmService.initialize()', data: 'shortCode=$userShortCode');

    await _requestPermission();

    final token = await _messaging.getToken();
    AppLogger.step(
      'FCM token retrieved',
      data: token != null ? '${token.substring(0, 20)}…' : 'null',
    );
    if (token != null) {
      await _saveToken(userShortCode, token);
    } else {
      AppLogger.warning('FCM token is null — skipping save');
    }

    _messaging.onTokenRefresh.listen((t) {
      AppLogger.step('FCM token refreshed');
      _saveToken(userShortCode, t);
    });

    // Foreground messages — show via local notifications
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Background → foreground via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      AppLogger.step('FCM onMessageOpenedApp', data: 'data=${msg.data}');
      _route(msg.data['action'] as String?);
    });

    // Terminated → opened via notification tap
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      AppLogger.step(
        'FCM getInitialMessage (launched from notification)',
        data: 'data=${initial.data}',
      );
      _route(initial.data['action'] as String?);
    }

    AppLogger.success('FcmService ready for $userShortCode');
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    AppLogger.step('FCM permission', data: settings.authorizationStatus.name);

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.warning(
        'FCM permission denied — foreground notifications suppressed',
      );
    }
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<void> _saveToken(String shortCode, String token) async {
    AppLogger.step('Saving FCM token', data: 'shortCode=$shortCode');
    try {
      await _firestore.collection('users').doc(shortCode).update({
        'fcmToken': token,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      AppLogger.success('FCM token saved for $shortCode');
    } catch (e) {
      AppLogger.error('Failed to save FCM token for $shortCode', error: e);
    }
  }

  // ── Foreground message ────────────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    AppLogger.step(
      'FCM foreground message',
      data: 'id=${message.messageId} data=${message.data}',
    );

    final notification = message.notification;
    if (notification == null) {
      // Data-only message — no visual needed
      AppLogger.step('FCM data-only message, no notification to show');
      return;
    }

    final action = message.data['action'] as String?;

    _localNotifications.show(
      // Use hashCode of messageId for a stable int ID; fallback to 0
      message.messageId?.hashCode ?? 0,
      notification.title ?? 'NeoShare',
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // Payload carries the action so the tap callback can route correctly
      payload: action,
    );
  }

  // ── Routing ───────────────────────────────────────────────────────────────

  void _route(String? action) {
    if (action == null) {
      AppLogger.warning('FCM route: action is null, ignoring');
      return;
    }
    AppLogger.step('FCM routing', data: 'action=$action');
    switch (action) {
      case 'open_receive':
        _router.go('/receive');
      default:
        AppLogger.warning('FCM route: unknown action=$action');
    }
  }
}

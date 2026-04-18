import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Top-level function — required by FCM for background handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // App is in background or terminated.
  // Firebase is already initialized by the time this fires.
  // Actual handling happens when user taps and app opens in the foreground.
}

class FcmService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  FcmService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
  })  : _messaging = messaging,
        _firestore = firestore;

  Future<void> initialize(String userShortCode) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (Platform.isIOS || Platform.isAndroid) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // Degrade gracefully; foreground transfers still work via firestore listeners.
        return;
      }
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveFcmToken(userShortCode, token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      _saveFcmToken(userShortCode, newToken);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleDeepLink(message);
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleDeepLink(initial);
    }
  }

  Future<void> _saveFcmToken(String shortCode, String token) async {
    await _firestore.collection('users').doc(shortCode).update({
      'fcmToken': token,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  void _handleDeepLink(RemoteMessage message) {
    // Navigate to inbox — logic can be fleshed out with AppRouter/GoRouter later
    final transferId = message.data['transferId'] as String?;
    if (transferId == null) return;
    
    // e.g. sl<GoRouter>().go('/receive');
  }
}

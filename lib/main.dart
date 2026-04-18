import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:neoshare/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/di/service_locator.dart';
import 'core/notifications/fcm_service.dart';
import 'core/notifications/notification_permission_service.dart';
import 'core/utils/app_logger.dart';
import 'features/identity/presentation/bloc/identity_bloc.dart';

/// Application bootstrap for NeoShare.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.step('App bootstrap started');

  try {
    AppLogger.step('Initializing Firebase');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.success('Firebase initialized');

    // Register FCM background handler exactly once at startup.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialise local notifications before runApp.
    await initLocalNotifications();

    // Capture terminated-state message BEFORE runApp so it isn't lost.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.step(
        'FCM initial message captured in main()',
        data: 'data=${initialMessage.data}',
      );
    }

    AppLogger.step('Setting up service locator');
    await setupServiceLocator();
    AppLogger.success('Service locator configured');

    AppLogger.step('Requesting notification permission');
    await sl<NotificationPermissionService>().requestIfNeeded();
    AppLogger.success('Notification permission check complete');

    runApp(NeoShareApp(initialFcmMessage: initialMessage));
    AppLogger.success('NeoShare app launched');
  } catch (error, stackTrace) {
    AppLogger.error(
      'App bootstrap failed. Firebase configuration may be missing.',
      error: error,
      stackTrace: stackTrace,
    );
    runApp(BootstrapErrorApp(errorMessage: error.toString()));
  }
}

/// Root widget that wires app-level theme and initial route.
class NeoShareApp extends StatefulWidget {
  const NeoShareApp({super.key, this.initialFcmMessage});

  final RemoteMessage? initialFcmMessage;

  @override
  State<NeoShareApp> createState() => _NeoShareAppState();
}

class _NeoShareAppState extends State<NeoShareApp> {
  @override
  void initState() {
    super.initState();

    // Background tap: app was alive but backgrounded — fires immediately
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      AppLogger.step('FCM onMessageOpenedApp (main)', data: 'data=${msg.data}');
      _navigateFromFcmData(msg.data);
    });

    // Terminated tap: navigate after first frame so router/shell is mounted
    if (widget.initialFcmMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLogger.step(
          'FCM initial message navigating post-frame',
          data: 'data=${widget.initialFcmMessage!.data}',
        );
        _navigateFromFcmData(widget.initialFcmMessage!.data);
      });
    }
  }

  void _navigateFromFcmData(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    final router = sl<GoRouter>();
    if (action == 'open_receive') {
      router.go('/receive');
    } else {
      AppLogger.warning('FCM main nav: unknown action=$action');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IdentityBloc>(
      create: (_) =>
          sl<IdentityBloc>()..add(const IdentityProvisionRequested()),
      child: MaterialApp.router(
        title: 'NeoShare',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          scaffoldBackgroundColor: const Color(0xFFFDFDFF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.8,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3157E1),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        routerConfig: sl<GoRouter>(),
      ),
    );
  }
}

/// Fallback UI shown when startup fails before normal app rendering.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({required this.errorMessage, super.key});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Startup Error')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Failed to initialize app.\n$errorMessage',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

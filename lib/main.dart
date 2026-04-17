import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:neoshare/firebase_options.dart';

import 'core/di/service_locator.dart';
import 'core/utils/app_logger.dart';
import 'features/identity/presentation/bloc/identity_bloc.dart';
import 'features/identity/presentation/pages/onboarding_page.dart';

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

    AppLogger.step('Setting up service locator');
    await setupServiceLocator();
    AppLogger.success('Service locator configured');

    runApp(const NeoShareApp());
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
class NeoShareApp extends StatelessWidget {
  const NeoShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IdentityBloc>(
      create: (_) => sl<IdentityBloc>()..add(const IdentityProvisionRequested()),
      child: MaterialApp(
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
        home: const OnboardingPage(),
      ),
    );
  }
}

/// Fallback UI shown when startup fails before normal app rendering.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({
    required this.errorMessage,
    super.key,
  });

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

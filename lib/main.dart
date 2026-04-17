import 'package:flutter/material.dart';

import 'features/identity/presentation/pages/onboarding_page.dart';

/// Application bootstrap for NeoShare.
void main() {
  runApp(const NeoShareApp());
}

/// Root widget that wires app-level theme and initial route.
class NeoShareApp extends StatelessWidget {
  const NeoShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeoShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const OnboardingPage(),
    );
  }
}

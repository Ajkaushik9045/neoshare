import 'package:flutter/material.dart';

/// Starter onboarding page for Phase 1 architecture handoff.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NeoShare Onboarding')),
      body: const Center(
        child: Text(
          'Phase 1 scaffold is ready.\nIdentity flow UI comes in Phase 2.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

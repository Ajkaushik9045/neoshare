import 'package:flutter/material.dart';

/// Placeholder send page for transfer workflow.
class SendPage extends StatelessWidget {
  const SendPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Files')),
      body: const Center(
        child: Text(
          'Send flow UI scaffold.\nBLoC wiring and actions arrive in Phase 2.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

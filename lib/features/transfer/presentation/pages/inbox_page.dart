import 'package:flutter/material.dart';

/// Placeholder inbox page for received transfer listing.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Transfers')),
      body: const Center(
        child: Text(
          'Inbox UI scaffold.\nRealtime list handling arrives in Phase 2.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A slim banner warning the user that battery is low during an upload.
class BatteryWarningBanner extends StatelessWidget {
  const BatteryWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      content: const Text(
        'Battery is low. Transfer may take longer or pause while backgrounded.',
      ),
      leading: const Icon(Icons.battery_alert, color: Colors.orange),
      actions: const [SizedBox.shrink()],
    );
  }
}

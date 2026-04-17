import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Cross-platform primary action button.
class PlatformActionButton extends StatelessWidget {
  const PlatformActionButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        child: Text(label),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

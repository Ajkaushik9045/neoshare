import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Cross-platform primary action button.
class PlatformActionButton extends StatelessWidget {
  const PlatformActionButton({
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.isExpanded = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      final button = CupertinoButton.filled(
        onPressed: onPressed,
        padding: EdgeInsets.symmetric(vertical: (height - 20) / 2),
        child: Text(label),
      );
      if (isExpanded) {
        return SizedBox(width: double.infinity, child: button);
      }
      return button;
    }

    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

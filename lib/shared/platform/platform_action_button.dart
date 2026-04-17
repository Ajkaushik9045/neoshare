import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/app_platform_indicator.dart';

/// Cross-platform primary action button.
class PlatformActionButton extends StatelessWidget {
  const PlatformActionButton({
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.isExpanded = false,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool isExpanded;
  final bool isLoading;

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: AppPlatformIndicator(color: Colors.white, radius: 10),
      );
    }
    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isMacOS) {
      final button = CupertinoButton.filled(
        onPressed: isLoading ? null : onPressed,
        padding: EdgeInsets.symmetric(vertical: (height - 20) / 2),
        child: _buildChild(),
      );
      if (isExpanded) {
        return SizedBox(width: double.infinity, child: button);
      }
      return button;
    }

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _buildChild(),
    );

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

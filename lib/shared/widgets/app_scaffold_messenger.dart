import 'package:flutter/material.dart';

/// Global helper for consistent app snackbars.
class AppScaffoldMessenger {
  AppScaffoldMessenger._();

  static void showInfo(BuildContext context, String message) {
    _show(context, message, _Palette.infoBackground, _Palette.infoBorder);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, _Palette.errorBackground, _Palette.errorBorder);
  }

  static void _show(
    BuildContext context,
    String message,
    Color backgroundColor,
    Color borderColor,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      ),
    );
  }
}

class _Palette {
  _Palette._();

  static const Color infoBackground = Color(0xFFE8F0FE);
  static const Color infoBorder = Color(0xFFB6CCFF);
  static const Color errorBackground = Color(0xFFFDECEC);
  static const Color errorBorder = Color(0xFFF4B4B4);
}

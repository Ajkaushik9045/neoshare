import 'package:flutter/material.dart';

/// Global helper for consistent app snackbars.
class AppScaffoldMessenger {
  AppScaffoldMessenger._();

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Colors.blueGrey);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.redAccent);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

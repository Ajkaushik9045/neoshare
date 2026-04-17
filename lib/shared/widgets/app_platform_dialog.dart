import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared platform-native alert dialog helper.
class AppPlatformDialog {
  AppPlatformDialog._();

  static Future<void> showMessage({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    if (Platform.isIOS) {
      return showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

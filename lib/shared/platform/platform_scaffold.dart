import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Cross-platform scaffold that renders native page chrome.
class PlatformScaffold extends StatelessWidget {
  const PlatformScaffold({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
        ),
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

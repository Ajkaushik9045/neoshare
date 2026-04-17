import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Cross-platform scaffold that renders native page chrome.
class PlatformScaffold extends StatelessWidget {
  const PlatformScaffold({
    required this.body,
    this.title,
    this.bottomBar,
    super.key,
  });

  final String? title;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[Expanded(child: body)];
    if (bottomBar != null) {
      children.add(bottomBar!);
    }

    final content = Column(
      children: children,
    );

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.paperplane_fill, size: 18),
              const SizedBox(width: 6),
              Text(title ?? 'NeoShare'),
            ],
          ),
        ),
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              child: Icon(Icons.send_rounded, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title ?? 'NeoShare'),
          ],
        ),
      ),
      body: content,
    );
  }
}

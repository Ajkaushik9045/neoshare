import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A platform-aware loading indicator that uses CupertinoActivityIndicator
/// on iOS/macOS and CircularProgressIndicator on other platforms.
class AppPlatformIndicator extends StatelessWidget {
  const AppPlatformIndicator({super.key, this.radius, this.color});

  final double? radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isMacOS) {
      return CupertinoActivityIndicator(
        radius: radius ?? 10.0,
        color: color,
      );
    }
    return CircularProgressIndicator(
      color: color,
    );
  }
}

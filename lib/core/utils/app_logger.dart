import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Centralized logger used to trace app progress and failures.
class AppLogger {
  AppLogger._();

  static const String _name = 'NeoShare';

  static void step(String message, {Object? data}) {
    _log('STEP', message, data: data);
  }

  static void success(String message, {Object? data}) {
    _log('SUCCESS', message, data: data);
  }

  static void warning(String message, {Object? data}) {
    _log('WARNING', message, data: data);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Object? data,
  }) {
    final fullMessage = data == null ? message : '$message | data: $data';
    developer.log(
      'ERROR | $fullMessage',
      name: _name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    if (kDebugMode) {
      debugPrint('NeoShare ERROR | $fullMessage');
      if (error != null) debugPrint('NeoShare ERROR DETAILS | $error');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
  }

  static void _log(String level, String message, {Object? data}) {
    final fullMessage = data == null ? message : '$message | data: $data';
    developer.log('$level | $fullMessage', name: _name);
    if (kDebugMode) {
      debugPrint('NeoShare $level | $fullMessage');
    }
  }
}

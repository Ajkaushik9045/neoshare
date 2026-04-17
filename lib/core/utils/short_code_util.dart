import 'dart:math';

import '../constants/app_constants.dart';

/// Utility helpers for short-code generation and formatting.
class ShortCodeUtil {
  ShortCodeUtil._();

  static final Random _random = Random.secure();

  /// Generates a random uppercase short code from the safe alphabet.
  static String generateRawCode() {
    final chars = List.generate(
      AppConstants.shortCodeLength,
      (_) {
        final index = _random.nextInt(AppConstants.safeShortCodeAlphabet.length);
        return AppConstants.safeShortCodeAlphabet[index];
      },
    );
    return chars.join();
  }

  /// Formats raw six-character codes as `XXX-XXX`.
  static String formatForDisplay(String rawCode) {
    if (rawCode.length != AppConstants.shortCodeLength) {
      return rawCode.toUpperCase();
    }
    return '${rawCode.substring(0, 3)}-${rawCode.substring(3)}';
  }

  /// Normalizes user input by removing separators and uppercasing.
  static String normalize(String input) {
    return input.replaceAll('-', '').trim().toUpperCase();
  }
}

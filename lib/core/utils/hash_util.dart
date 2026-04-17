import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Utility methods for deterministic hashing.
class HashUtil {
  HashUtil._();

  /// Generates SHA-256 hash for an input string.
  static String sha256Of(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

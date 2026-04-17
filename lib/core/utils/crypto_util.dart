import 'dart:io';
import 'package:crypto/crypto.dart';

/// Utility class to handle cryptography related operations.
class CryptoUtil {
  const CryptoUtil._();

  /// Computes the SHA-256 hash of a file efficiently by streaming it in chunks.
  /// 
  /// This prevents out-of-memory errors on large files since it doesn't load
  /// the entire file into memory at once.
  static Future<String> computeFileSha256(File file) async {
    final stream = file.openRead();
    final hash = await sha256.bind(stream).first;
    return hash.toString();
  }
}

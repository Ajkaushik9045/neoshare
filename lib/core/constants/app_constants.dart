/// Shared application constants.
class AppConstants {
  AppConstants._();

  /// Stable alphabet used for short IDs and invite codes.
  static const String alphaNumeric =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// Default transfer metadata TTL in minutes.
  static const int defaultTransferTtlMinutes = 60;

  /// Max upload size (in bytes) for MVP flow.
  static const int maxFileSizeBytes = 100 * 1024 * 1024;
}

/// Shared application constants.
class AppConstants {
  AppConstants._();

  /// Safe alphabet that avoids ambiguous characters.
  static const String safeShortCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Length of canonical short code before display formatting.
  static const int shortCodeLength = 6;

  /// Default transfer metadata TTL in minutes.
  static const int defaultTransferTtlMinutes = 60;

  /// Firestore inactivity window before identity cleanup policy applies.
  static const int userInactivityExpiryDays = 30;

  /// Max upload size (in bytes) for MVP flow.
  static const int maxFileSizeBytes = 100 * 1024 * 1024;
}

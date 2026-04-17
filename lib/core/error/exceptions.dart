/// Base exception for data-source layer.
class AppException implements Exception {
  AppException(this.message);

  final String message;

  @override
  String toString() => 'AppException: $message';
}

/// Thrown when a remote API/storage call fails.
class ServerException extends AppException {
  ServerException(super.message);
}

/// Thrown when reading/writing local cache fails.
class CacheException extends AppException {
  CacheException(super.message);
}

class AppException implements Exception {
  AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class CacheException extends AppException {
  CacheException(super.message);
}


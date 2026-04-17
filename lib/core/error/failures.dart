import 'package:equatable/equatable.dart';

/// Base failure type used by domain and data layers.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Represents server-side operation failures.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Represents local cache or persistence failures.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

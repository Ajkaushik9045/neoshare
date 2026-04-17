import 'package:equatable/equatable.dart';

/// Core identity entity used across app layers.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.createdAtIso,
  });

  final String id;
  final String displayName;
  final String createdAtIso;

  @override
  List<Object?> get props => [id, displayName, createdAtIso];
}

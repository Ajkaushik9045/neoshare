import 'package:equatable/equatable.dart';

/// Core identity entity used across app layers.
class AppUser extends Equatable {
  const AppUser({
    required this.shortCode,
    required this.uid,
    required this.fcmToken,
  });

  final String shortCode;
  final String uid;
  final String fcmToken;

  @override
  List<Object?> get props => [shortCode, uid, fcmToken];
}

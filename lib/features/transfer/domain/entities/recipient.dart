import 'package:equatable/equatable.dart';

/// Resolved recipient identity data fetched by short code.
class Recipient extends Equatable {
  const Recipient({
    required this.uid,
    required this.fcmToken,
  });

  final String uid;
  final String fcmToken;

  @override
  List<Object?> get props => [uid, fcmToken];
}

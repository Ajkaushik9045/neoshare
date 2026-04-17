part of 'send_bloc.dart';

/// Send flow events.
sealed class SendEvent extends Equatable {
  const SendEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when sender confirms files and receiver.
class SendRequested extends SendEvent {
  const SendRequested({
    required this.senderShortCode,
    required this.recipientShortCode,
  });

  final String senderShortCode;
  final String recipientShortCode;

  @override
  List<Object?> get props => [senderShortCode, recipientShortCode];
}

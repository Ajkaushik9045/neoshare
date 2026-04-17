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
    required this.files,
  });

  final String senderShortCode;
  final String recipientShortCode;
  final List<TransferFile> files;

  @override
  List<Object?> get props => [senderShortCode, recipientShortCode, files];
}

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
    required this.receiverId,
    required this.files,
  });

  final String receiverId;
  final List<TransferFile> files;

  @override
  List<Object?> get props => [receiverId, files];
}

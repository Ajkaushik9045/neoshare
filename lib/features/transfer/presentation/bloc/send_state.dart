part of 'send_bloc.dart';

/// Send flow states.
sealed class SendState extends Equatable {
  const SendState();

  @override
  List<Object?> get props => [];
}

/// Idle state before transfer request.
class SendInitial extends SendState {
  const SendInitial();
}

/// Loading state while transfer operation executes.
class SendLoading extends SendState {
  const SendLoading();
}

/// Success state with created transfer payload.
class SendSuccess extends SendState {
  const SendSuccess(this.recipient);

  final Recipient recipient;

  @override
  List<Object?> get props => [recipient];
}

/// Error state for invalid recipient or send failures.
class SendError extends SendState {
  const SendError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

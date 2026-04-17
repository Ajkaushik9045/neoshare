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
  const SendSuccess(this.transfer);

  final Transfer transfer;

  @override
  List<Object?> get props => [transfer];
}

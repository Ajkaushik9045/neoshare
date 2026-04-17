import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';
import '../../domain/usecases/send_transfer.dart';

part 'send_event.dart';
part 'send_state.dart';

/// BLoC responsible for send transfer interactions.
class SendBloc extends Bloc<SendEvent, SendState> {
  SendBloc(this._sendTransfer) : super(const SendInitial()) {
    on<SendRequested>(_onSendRequested);
  }

  final SendTransfer _sendTransfer;

  Future<void> _onSendRequested(
    SendRequested event,
    Emitter<SendState> emit,
  ) async {
    emit(const SendLoading());
    final transfer = await _sendTransfer(
      receiverId: event.receiverId,
      files: event.files,
    );
    emit(SendSuccess(transfer));
  }
}

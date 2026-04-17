import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/app_logger.dart';
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
    AppLogger.step(
      'SendBloc send requested',
      data: 'sender=${event.senderShortCode}, receiver=${event.recipientShortCode}',
    );
    emit(const SendLoading());
    try {
      final transfer = await _sendTransfer(
        senderShortCode: event.senderShortCode,
        recipientShortCode: event.recipientShortCode,
        files: event.files,
      );
      AppLogger.success('SendBloc transfer created', data: transfer.id);
      emit(SendSuccess(transfer));
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendBloc send failed',
        error: error,
        stackTrace: stackTrace,
      );
      emit(SendError(error.toString().replaceFirst('Exception: ', '')));
    }
  }
}

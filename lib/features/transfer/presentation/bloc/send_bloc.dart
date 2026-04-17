import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/recipient.dart';
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
      final recipient = await _sendTransfer(
        senderShortCode: event.senderShortCode,
        recipientShortCode: event.recipientShortCode,
      );
      AppLogger.success('SendBloc recipient lookup success', data: recipient.uid);
      emit(SendSuccess(recipient));
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendBloc send failed',
        error: error,
        stackTrace: stackTrace,
      );
      emit(SendError(_friendlyMessage(error)));
    }
  }

  String _friendlyMessage(Object error) {
    final raw = error.toString();
    final stripped = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('FirebaseException: ', '')
        .trim();
    if (stripped.isEmpty || stripped == 'null') {
      return 'Something went wrong while validating recipient. Please try again.';
    }
    return stripped;
  }
}

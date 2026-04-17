import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/transfer.dart';
import '../../domain/usecases/watch_incoming.dart';

part 'inbox_event.dart';
part 'inbox_state.dart';

/// BLoC responsible for observing incoming transfers.
class InboxBloc extends Bloc<InboxEvent, InboxState> {
  InboxBloc(this._watchIncoming) : super(const InboxInitial()) {
    on<InboxStarted>(_onStarted);
    on<InboxUpdated>(_onUpdated);
  }

  final WatchIncoming _watchIncoming;
  StreamSubscription<List<Transfer>>? _subscription;

  Future<void> _onStarted(InboxStarted event, Emitter<InboxState> emit) async {
    await _subscription?.cancel();
    _subscription = _watchIncoming(receiverId: event.receiverId).listen(
      (transfers) => add(InboxUpdated(transfers)),
    );
  }

  void _onUpdated(InboxUpdated event, Emitter<InboxState> emit) {
    emit(InboxLoaded(event.transfers));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

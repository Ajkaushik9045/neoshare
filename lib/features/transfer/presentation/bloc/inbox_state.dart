part of 'inbox_bloc.dart';

/// Incoming transfer states.
sealed class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

/// Initial inbox state.
class InboxInitial extends InboxState {
  const InboxInitial();
}

/// Loaded state for current incoming transfer list.
class InboxLoaded extends InboxState {
  const InboxLoaded(this.transfers);

  final List<Transfer> transfers;

  @override
  List<Object?> get props => [transfers];
}

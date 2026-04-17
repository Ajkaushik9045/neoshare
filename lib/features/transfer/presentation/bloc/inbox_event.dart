part of 'inbox_bloc.dart';

/// Incoming transfer events.
sealed class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

/// Starts listening for incoming transfers for the given receiver.
class InboxStarted extends InboxEvent {
  const InboxStarted(this.receiverId);

  final String receiverId;

  @override
  List<Object?> get props => [receiverId];
}

/// Internal event emitted when stream provides new transfers.
class InboxUpdated extends InboxEvent {
  const InboxUpdated(this.transfers);

  final List<Transfer> transfers;

  @override
  List<Object?> get props => [transfers];
}

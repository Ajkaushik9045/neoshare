part of 'inbox_bloc.dart';


sealed class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {}

class InboxLoading extends InboxState {}

class InboxLoaded extends InboxState {
  final List<Transfer> transfers;
  // Track which transferIds are actively downloading (in-progress)
  final Set<String> activeDownloads;
  // Track individual fileIds that have been locally saved to device
  final Set<String> savedFileIds;
  // Track full transferIds where ALL files are saved
  final Set<String> savedTransferIds;
  // Map of transferId → error string for failures
  final Map<String, String> errors;

  const InboxLoaded({
    required this.transfers,
    this.activeDownloads = const {},
    this.savedFileIds = const {},
    this.savedTransferIds = const {},
    this.errors = const {},
  });

  InboxLoaded copyWith({
    List<Transfer>? transfers,
    Set<String>? activeDownloads,
    Set<String>? savedFileIds,
    Set<String>? savedTransferIds,
    Map<String, String>? errors,
  }) =>
      InboxLoaded(
        transfers: transfers ?? this.transfers,
        activeDownloads: activeDownloads ?? this.activeDownloads,
        savedFileIds: savedFileIds ?? this.savedFileIds,
        savedTransferIds: savedTransferIds ?? this.savedTransferIds,
        errors: errors ?? this.errors,
      );

  @override
  List<Object?> get props => [transfers, activeDownloads, savedFileIds, savedTransferIds, errors];
}

class InboxError extends InboxState {
  final String message;
  const InboxError(this.message);
  @override
  List<Object?> get props => [message];
}

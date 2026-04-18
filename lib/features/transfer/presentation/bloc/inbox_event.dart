
// ─── EVENTS ────────────────────────────────────────────────────────────────

part of 'inbox_bloc.dart';

sealed class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

class InboxStarted extends InboxEvent {
  const InboxStarted();
}

/// Internal — fires when a download stream closes to guarantee activeDownloads is cleared.
class _DownloadCleared extends InboxEvent {
  final String downloadKey;
  const _DownloadCleared(this.downloadKey);
  @override
  List<Object?> get props => [downloadKey];
}

class TransfersUpdated extends InboxEvent {
  final List<Transfer> transfers;
  const TransfersUpdated(this.transfers);
  @override
  List<Object?> get props => [transfers];
}

/// Trigger download of ALL files in a transfer. Pigeon handles MediaStore write.
class DownloadRequested extends InboxEvent {
  final String transferId;
  const DownloadRequested(this.transferId);
  @override
  List<Object?> get props => [transferId];
}

/// Trigger download of a single file. Pigeon handles MediaStore write.
class DownloadFileRequested extends InboxEvent {
  final String transferId;
  final String fileId;
  const DownloadFileRequested(this.transferId, this.fileId);
  @override
  List<Object?> get props => [transferId, fileId];
}

class DownloadProgressUpdated extends InboxEvent {
  final Transfer transfer;
  const DownloadProgressUpdated(this.transfer);
  @override
  List<Object?> get props => [transfer];
}

class TransferFailed extends InboxEvent {
  final String transferId;
  final String reason;
  /// The exact key in activeDownloads to remove (may be composite 'transferId_fileId').
  final String? downloadKey;
  const TransferFailed(this.transferId, this.reason, {this.downloadKey});
  @override
  List<Object?> get props => [transferId, reason, downloadKey];
}

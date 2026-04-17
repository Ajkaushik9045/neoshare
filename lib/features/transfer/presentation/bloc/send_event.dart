part of 'send_bloc.dart';

sealed class SendEvent extends Equatable {
  const SendEvent();
  @override List<Object?> get props => [];
}

class LookupRecipient extends SendEvent {
  const LookupRecipient({required this.senderShortCode, required this.recipientShortCode});
  final String senderShortCode;
  final String recipientShortCode;
  @override List<Object?> get props => [senderShortCode, recipientShortCode];
}

class FilesChosen extends SendEvent {
  const FilesChosen(this.files);
  final List<PlatformFile> files;
  @override List<Object?> get props => [files];
}

class UploadConfirmed extends SendEvent {
  const UploadConfirmed();
}

class UploadProgressUpdated extends SendEvent {
  const UploadProgressUpdated({required this.fileId, required this.progress});
  final String fileId;
  final double progress;
  @override List<Object?> get props => [fileId, progress];
}

class UploadFinished extends SendEvent {
  const UploadFinished();
}

class UploadErrored extends SendEvent {
  const UploadErrored(this.reason);
  final String reason;
  @override List<Object?> get props => [reason];
}

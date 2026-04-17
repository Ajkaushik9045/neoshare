part of 'send_bloc.dart';

sealed class SendState extends Equatable {
  const SendState();
  @override List<Object?> get props => [];
}

class SendIdle extends SendState { const SendIdle(); }

class LookingUpRecipient extends SendState { const LookingUpRecipient(); }

class PreparingUpload extends SendState { const PreparingUpload(); }

class RecipientFound extends SendState {
  const RecipientFound(this.displayCode, this.recipientUid);
  final String displayCode;
  final String recipientUid;
  @override List<Object?> get props => [displayCode, recipientUid];
}

class RecipientNotFound extends SendState {
  const RecipientNotFound(this.reason);
  final String reason;
  @override List<Object?> get props => [reason];
}

class FilesSelected extends SendState {
  const FilesSelected(this.files, {this.isMetered = false});
  final List<PlatformFile> files;
  final bool isMetered;
  @override List<Object?> get props => [files, isMetered];
}

class Uploading extends SendState {
  const Uploading({
    required this.fileProgress,
    required this.totalProgress,
  });
  final Map<String, double> fileProgress; // fileId -> 0.0..1.0
  final double totalProgress;
  @override List<Object?> get props => [fileProgress, totalProgress];
}

class UploadComplete extends SendState { const UploadComplete(); }

class UploadFailed extends SendState {
  const UploadFailed(this.reason);
  final String reason;
  @override List<Object?> get props => [reason];
}

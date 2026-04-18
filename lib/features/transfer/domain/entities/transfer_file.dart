import 'package:equatable/equatable.dart';

enum FileStatus { pending, downloading, complete, failed, corrupted }

/// Domain entity describing a single file in a transfer.
class TransferFile extends Equatable {
  const TransferFile({
    required this.fileId,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.storagePath,
    required this.sha256,
    this.status = FileStatus.pending,
    this.bytesUploaded = 0,
    this.bytesDownloaded = 0,
  });

  final String fileId;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String storagePath;
  final String sha256;
  final FileStatus status;
  final int bytesUploaded;
  final int bytesDownloaded;

  double get progress => sizeBytes == 0 ? 0 : bytesDownloaded / sizeBytes;

  TransferFile copyWith({
    FileStatus? status,
    int? bytesUploaded,
    int? bytesDownloaded,
  }) =>
      TransferFile(
        fileId: fileId,
        name: name,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        storagePath: storagePath,
        sha256: sha256,
        status: status ?? this.status,
        bytesUploaded: bytesUploaded ?? this.bytesUploaded,
        bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      );

  @override
  List<Object?> get props => [
        fileId,
        name,
        mimeType,
        sizeBytes,
        storagePath,
        sha256,
        status,
        bytesUploaded,
        bytesDownloaded,
      ];
}

import 'package:equatable/equatable.dart';

/// Domain entity describing a single file in a transfer.
class TransferFile extends Equatable {
  const TransferFile({
    required this.fileId,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    required this.storagePath,
    required this.sha256,
    required this.status,
    required this.bytesUploaded,
  });

  final String fileId;
  final String name;
  final int sizeBytes;
  final String mimeType;
  final String storagePath;
  final String sha256;
  final String status;
  final int bytesUploaded;

  @override
  List<Object?> get props => [
        fileId,
        name,
        sizeBytes,
        mimeType,
        storagePath,
        sha256,
        status,
        bytesUploaded,
      ];
}

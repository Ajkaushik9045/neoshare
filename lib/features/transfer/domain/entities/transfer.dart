import 'package:equatable/equatable.dart';

import 'transfer_file.dart';

enum TransferStatus { pending, transferring, complete, failed, expired }

/// Domain aggregate representing a transfer operation.
class Transfer extends Equatable {
  const Transfer({
    required this.transferId,
    this.senderId = '',
    required this.senderCode,
    this.recipientCode = '',
    this.recipientUid = '',
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.files,
  });

  final String transferId;
  final String senderId;
  final String senderCode;
  final String recipientCode;
  final String recipientUid;
  final TransferStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<TransferFile> files;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  double get totalProgress {
    if (files.isEmpty) return 0;
    final totalBytes = files.fold(0, (sum, f) => sum + f.sizeBytes);
    final downloadedBytes = files.fold(0, (sum, f) => sum + f.bytesDownloaded);
    return totalBytes == 0 ? 0 : downloadedBytes / totalBytes;
  }

  @override
  List<Object?> get props => [
        transferId,
        senderId,
        senderCode,
        recipientCode,
        recipientUid,
        status,
        createdAt,
        expiresAt,
        files,
      ];
}

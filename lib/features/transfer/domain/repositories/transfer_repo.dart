import 'dart:io';
import '../entities/recipient.dart';
import '../entities/transfer.dart';
import '../entities/transfer_file.dart';

/// Domain abstraction for transfer operations.
abstract class TransferRepo {
  Future<Recipient> validateRecipientCode({
    required String senderShortCode,
    required String recipientShortCode,
  });

  Future<Transfer> createPendingTransfer({
    required String transferId,
    required String senderId,
    required String senderCode,
    required String recipientCode,
    required String recipientUid,
    required List<TransferFile> files,
  });

  Future<void> updateTransferStatus(String transferId, TransferStatus status);

  Stream<double> uploadFile(TransferFile fileDesc, File localFile, String transferId);

  Future<void> updateFileProgress(
    String transferId,
    String fileId,
    int? bytesUploaded,
    int? bytesDownloaded,
    FileStatus status, {
    String? sha256,
  });

  Stream<List<Transfer>> watchIncoming({required String receiverId});

  /// Downloads either the specified file or all pending files of a transfer. Saves via Pigeon/MediaStore.
  Stream<Transfer> downloadTransfer(String transferId, [String? specificFileId]);
}

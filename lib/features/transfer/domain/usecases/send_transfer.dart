import '../entities/transfer.dart';
import '../entities/transfer_file.dart';
import '../repositories/transfer_repo.dart';

/// Use case for starting a file transfer.
class SendTransfer {
  SendTransfer(this._transferRepo);

  final TransferRepo _transferRepo;

  Future<Transfer> call({
    required String senderShortCode,
    required String recipientShortCode,
    required List<TransferFile> files,
  }) async {
    final recipient = await _transferRepo.validateRecipientCode(
      senderShortCode: senderShortCode,
      recipientShortCode: recipientShortCode,
    );
    return _transferRepo.sendTransfer(receiverId: recipient.uid, files: files);
  }
}

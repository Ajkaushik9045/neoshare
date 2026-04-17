import '../entities/recipient.dart';
import '../repositories/transfer_repo.dart';

/// Use case for starting a file transfer.
class SendTransfer {
  SendTransfer(this._transferRepo);

  final TransferRepo _transferRepo;

  Future<Recipient> call({
    required String senderShortCode,
    required String recipientShortCode,
  }) async {
    return _transferRepo.validateRecipientCode(
      senderShortCode: senderShortCode,
      recipientShortCode: recipientShortCode,
    );
  }
}

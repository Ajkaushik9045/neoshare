import '../entities/recipient.dart';
import '../entities/transfer.dart';
import '../entities/transfer_file.dart';

/// Domain abstraction for transfer operations.
abstract class TransferRepo {
  Future<Recipient> validateRecipientCode({
    required String senderShortCode,
    required String recipientShortCode,
  });

  Future<Transfer> sendTransfer({
    required String receiverId,
    required List<TransferFile> files,
  });

  Stream<List<Transfer>> watchIncoming({required String receiverId});
}

import '../entities/transfer.dart';
import '../entities/transfer_file.dart';
import '../repositories/transfer_repo.dart';

/// Use case for starting a file transfer.
class SendTransfer {
  SendTransfer(this._transferRepo);

  final TransferRepo _transferRepo;

  Future<Transfer> call({
    required String receiverId,
    required List<TransferFile> files,
  }) {
    return _transferRepo.sendTransfer(receiverId: receiverId, files: files);
  }
}

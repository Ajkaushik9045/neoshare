import '../entities/transfer.dart';
import '../repositories/transfer_repo.dart';

/// Use case for observing incoming transfers for current identity.
class WatchIncoming {
  WatchIncoming(this._transferRepo);

  final TransferRepo _transferRepo;

  Stream<List<Transfer>> call({required String receiverId}) {
    return _transferRepo.watchIncoming(receiverId: receiverId);
  }
}

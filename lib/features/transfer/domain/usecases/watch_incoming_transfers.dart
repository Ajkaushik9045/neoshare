import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/transfer.dart';
import '../repositories/transfer_repo.dart';

class WatchIncomingTransfers {
  final TransferRepo repository;
  WatchIncomingTransfers(this.repository);

  Stream<Either<Failure, List<Transfer>>> call(String recipientUid) async* {
    try {
      yield* repository
          .watchIncoming(receiverId: recipientUid)
          .map((models) => Right(models));
    } catch (e) {
      yield Left(ServerFailure(e.toString()));
    }
  }
}

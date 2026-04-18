import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/transfer.dart';
import '../repositories/transfer_repo.dart';

class DownloadTransfer {
  final TransferRepo repository;
  DownloadTransfer(this.repository);

  Stream<Either<Failure, Transfer>> call(String transferId, [String? specificFileId]) async* {
    try {
      yield* repository
          .downloadTransfer(transferId, specificFileId)
          .map((model) => Right(model));
    } catch (e) {
      yield Left(ServerFailure(e.toString()));
    }
  }
}

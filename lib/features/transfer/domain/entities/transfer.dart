import 'package:equatable/equatable.dart';

import 'transfer_file.dart';

/// Domain aggregate representing a transfer operation.
class Transfer extends Equatable {
  const Transfer({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.files,
    required this.createdAtIso,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final List<TransferFile> files;
  final String createdAtIso;

  @override
  List<Object?> get props => [id, senderId, receiverId, files, createdAtIso];
}

import 'package:equatable/equatable.dart';

import 'transfer_file.dart';

/// Domain aggregate representing a transfer operation.
class Transfer extends Equatable {
  const Transfer({
    required this.id,
    required this.senderId,
    required this.recipientCode,
    required this.recipientUid,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.files,
  });

  final String id;
  final String senderId;
  final String recipientCode;
  final String recipientUid;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<TransferFile> files;

  @override
  List<Object?> get props => [
        id,
        senderId,
        recipientCode,
        recipientUid,
        status,
        createdAt,
        expiresAt,
        files,
      ];
}

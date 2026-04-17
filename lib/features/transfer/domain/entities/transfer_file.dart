import 'package:equatable/equatable.dart';

/// Domain entity describing a single file in a transfer.
class TransferFile extends Equatable {
  const TransferFile({
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String name;
  final int sizeBytes;
  final String mimeType;

  @override
  List<Object?> get props => [name, sizeBytes, mimeType];
}

import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';

/// DTO for transfer document serialization.
class TransferModel extends Transfer {
  const TransferModel({
    required super.id,
    required super.senderId,
    required super.receiverId,
    required super.files,
    required super.createdAtIso,
  });

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>? ?? [])
        .map(
          (item) => TransferFile(
            name: (item as Map<String, dynamic>)['name'] as String? ?? '',
            sizeBytes: item['sizeBytes'] as int? ?? 0,
            mimeType: item['mimeType'] as String? ?? 'application/octet-stream',
          ),
        )
        .toList();

    return TransferModel(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      files: files,
      createdAtIso: json['createdAtIso'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'createdAtIso': createdAtIso,
      'files': files
          .map(
            (file) => {
              'name': file.name,
              'sizeBytes': file.sizeBytes,
              'mimeType': file.mimeType,
            },
          )
          .toList(),
    };
  }
}

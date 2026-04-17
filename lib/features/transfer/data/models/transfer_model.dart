import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';

/// DTO for transfer document serialization.
class TransferModel extends Transfer {
  const TransferModel({
    required super.id,
    required super.senderId,
    required super.recipientCode,
    required super.recipientUid,
    required super.status,
    required super.createdAt,
    required super.expiresAt,
    required super.files,
  });

  factory TransferModel.fromJson(Map<String, dynamic> json, String id) {
    final files = (json['files'] as List<dynamic>? ?? [])
        .map(
          (item) => TransferFile(
            fileId: item['fileId'] as String? ?? '',
            name: item['name'] as String? ?? '',
            sizeBytes: item['sizeBytes'] as int? ?? 0,
            mimeType: item['mimeType'] as String? ?? 'application/octet-stream',
            storagePath: item['storagePath'] as String? ?? '',
            sha256: item['sha256'] as String? ?? '',
            status: item['status'] as String? ?? 'uploading',
            bytesUploaded: item['bytesUploaded'] as int? ?? 0,
          ),
        )
        .toList();

    return TransferModel(
      id: id,
      senderId: json['senderId'] as String? ?? '',
      recipientCode: json['recipientCode'] as String? ?? '',
      recipientUid: json['recipientUid'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 48)),
      files: files,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'recipientCode': recipientCode,
      'recipientUid': recipientUid,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'files': files
          .map(
            (file) => {
              'fileId': file.fileId,
              'name': file.name,
              'sizeBytes': file.sizeBytes,
              'mimeType': file.mimeType,
              'storagePath': file.storagePath,
              'sha256': file.sha256,
              'status': file.status,
              'bytesUploaded': file.bytesUploaded,
            },
          )
          .toList(),
    };
  }
}

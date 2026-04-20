import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';

class TransferFileModel extends TransferFile {
  const TransferFileModel({
    required super.fileId,
    required super.name,
    required super.mimeType,
    required super.sizeBytes,
    required super.storagePath,
    required super.sha256,
    super.status = FileStatus.pending,
    super.bytesUploaded = 0,
    super.bytesDownloaded = 0,
  });

  factory TransferFileModel.fromMap(Map<String, dynamic> map) =>
      TransferFileModel(
        fileId: map['fileId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        storagePath: map['storagePath'] as String? ?? '',
        sha256: map['sha256'] as String? ?? '',
        status: _mapStatus(map['status'] as String?),
        bytesUploaded: (map['bytesUploaded'] as num?)?.toInt() ?? 0,
        bytesDownloaded: (map['bytesDownloaded'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
    'fileId': fileId,
    'name': name,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'storagePath': storagePath,
    'sha256': sha256,
    'status': status.name,
    'bytesUploaded': bytesUploaded,
    'bytesDownloaded': bytesDownloaded,
  };

  static FileStatus _mapStatus(String? s) => switch (s) {
    'downloading' => FileStatus.downloading,
    'complete' => FileStatus.complete,
    'failed' => FileStatus.failed,
    'corrupted' => FileStatus.corrupted,
    _ => FileStatus.pending,
  };
}

class TransferModel extends Transfer {
  const TransferModel({
    required super.transferId,
    super.senderId = '',
    required super.senderCode,
    super.recipientCode = '',
    super.recipientUid = '',
    required super.status,
    required super.createdAt,
    required super.expiresAt,
    required super.files,
  });

  factory TransferModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TransferModel(
      transferId: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderCode: data['senderCode'] as String? ?? '',
      recipientCode: data['recipientCode'] as String? ?? '',
      recipientUid: data['recipientUid'] as String? ?? '',
      status: mapStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 48)),
      files: (data['files'] as List<dynamic>? ?? [])
          .map((f) => TransferFileModel.fromMap(f as Map<String, dynamic>))
          .toList(),
    );
  }

  factory TransferModel.fromJson(Map<String, dynamic> json, String id) {
    return TransferModel(
      transferId: id,
      senderId: json['senderId'] as String? ?? '',
      senderCode: json['senderCode'] as String? ?? '',
      recipientCode: json['recipientCode'] as String? ?? '',
      recipientUid: json['recipientUid'] as String? ?? '',
      status: mapStatus(json['status'] as String?),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (json['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 48)),
      files: (json['files'] as List<dynamic>? ?? [])
          .map((f) => TransferFileModel.fromMap(f as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderCode': senderCode,
      'recipientCode': recipientCode,
      'recipientUid': recipientUid,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'files': files
          .map(
            (f) => (TransferFileModel(
              fileId: f.fileId,
              name: f.name,
              mimeType: f.mimeType,
              sizeBytes: f.sizeBytes,
              storagePath: f.storagePath,
              sha256: f.sha256,
              status: f.status,
              bytesUploaded: f.bytesUploaded,
              bytesDownloaded: f.bytesDownloaded,
            )).toMap(),
          )
          .toList(),
    };
  }

  static TransferStatus mapStatus(String? s) => switch (s) {
    'transferring' => TransferStatus.transferring,
    'complete' => TransferStatus.complete,
    'failed' => TransferStatus.failed,
    'expired' => TransferStatus.expired,
    _ => TransferStatus.pending,
  };
}

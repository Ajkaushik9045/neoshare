import '../../domain/entities/app_user.dart';

/// DTO for serializing identity records to/from Firestore.
class UserModel extends AppUser {
  const UserModel({
    required super.id,
    required super.displayName,
    required super.createdAtIso,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      createdAtIso: json['createdAtIso'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'createdAtIso': createdAtIso,
    };
  }
}

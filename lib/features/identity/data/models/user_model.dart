import '../../domain/entities/app_user.dart';

/// DTO for serializing identity records to/from Firestore.
class UserModel extends AppUser {
  const UserModel({
    required super.shortCode,
    required super.uid,
    required super.fcmToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      shortCode: json['shortCode'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      fcmToken: json['fcmToken'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shortCode': shortCode,
      'uid': uid,
      'fcmToken': fcmToken,
    };
  }
}

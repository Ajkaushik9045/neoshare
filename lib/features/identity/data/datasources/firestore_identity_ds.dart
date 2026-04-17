import '../models/user_model.dart';

/// Data source boundary for identity persistence in Firestore.
class FirestoreIdentityDataSource {
  /// Creates a starter user record.
  ///
  /// Placeholder implementation used during architecture setup.
  Future<UserModel> provisionUser({required String displayName}) async {
    return UserModel(
      id: 'temp-user-id',
      displayName: displayName,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );
  }
}

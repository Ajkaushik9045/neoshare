import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_model.dart';

/// Hive-backed local persistence for provisioned identity.
class LocalIdentityDataSource {
  LocalIdentityDataSource(this._box);

  static const String boxName = 'identity_box';
  static const String _shortCodeKey = 'shortCode';
  static const String _uidKey = 'uid';
  static const String _fcmTokenKey = 'fcmToken';

  final Box<dynamic> _box;

  UserModel? getCachedUser() {
    final shortCode = _box.get(_shortCodeKey) as String?;
    final uid = _box.get(_uidKey) as String?;
    if (shortCode == null || uid == null) {
      return null;
    }

    return UserModel(
      shortCode: shortCode,
      uid: uid,
      fcmToken: (_box.get(_fcmTokenKey) as String?) ?? '',
    );
  }

  Future<void> saveUser(UserModel user) async {
    await _box.put(_shortCodeKey, user.shortCode);
    await _box.put(_uidKey, user.uid);
    await _box.put(_fcmTokenKey, user.fcmToken);
  }
}

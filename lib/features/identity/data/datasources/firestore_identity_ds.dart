import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/app_logger.dart';
import '../models/user_model.dart';

/// Data source boundary for identity persistence in Firestore.
class FirestoreIdentityDataSource {
  FirestoreIdentityDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Tries to claim a short code atomically.
  ///
  /// Returns `null` when the code is already claimed.
  Future<UserModel?> claimShortCode({
    required String shortCode,
    required String uid,
    required String fcmToken,
  }) async {
    final docRef = _firestore.collection('users').doc(shortCode);
    AppLogger.step('Attempting transactional short-code claim', data: shortCode);

    try {
      final claimed = await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          return null;
        }

        final now = FieldValue.serverTimestamp();
        transaction.set(docRef, {
          'uid': uid,
          'fcmToken': fcmToken,
          'createdAt': now,
          'lastSeen': now,
        });

        return UserModel(shortCode: shortCode, uid: uid, fcmToken: fcmToken);
      });

      if (claimed == null) {
        AppLogger.warning('Short-code collision detected', data: shortCode);
      } else {
        AppLogger.success('Short code claimed in Firestore', data: shortCode);
      }
      return claimed;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Firestore short-code claim transaction failed',
        error: error,
        stackTrace: stackTrace,
        data: shortCode,
      );
      rethrow;
    }
  }

  /// Checks whether a recipient short code exists.
  Future<bool> userExistsByCode(String shortCode) async {
    try {
      final doc = await _firestore.collection('users').doc(shortCode).get();
      AppLogger.step(
        'Recipient code existence checked',
        data: '$shortCode -> ${doc.exists}',
      );
      return doc.exists;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to verify recipient short code',
        error: error,
        stackTrace: stackTrace,
        data: shortCode,
      );
      rethrow;
    }
  }
}

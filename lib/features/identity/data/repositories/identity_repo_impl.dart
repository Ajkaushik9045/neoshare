import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/identity_repo.dart';
import '../datasources/firestore_identity_ds.dart';
import '../datasources/local_identity_ds.dart';

/// Concrete repository bridging identity data source and domain contract.
class IdentityRepoImpl implements IdentityRepo {
  IdentityRepoImpl({
    required FirestoreIdentityDataSource identityDataSource,
    required LocalIdentityDataSource localIdentityDataSource,
    required FirebaseAuth firebaseAuth,
  })  : _identityDataSource = identityDataSource,
        _localIdentityDataSource = localIdentityDataSource,
        _firebaseAuth = firebaseAuth;

  final FirestoreIdentityDataSource _identityDataSource;
  final LocalIdentityDataSource _localIdentityDataSource;
  final FirebaseAuth _firebaseAuth;

  static const int _maxCollisionRetries = 10;

  @override
  Future<AppUser> provisionIdentity() async {
    AppLogger.step('Identity provisioning started');
    final cachedUser = _localIdentityDataSource.getCachedUser();
    if (cachedUser != null) {
      AppLogger.success(
        'Identity restored from local cache',
        data: cachedUser.shortCode,
      );
      return cachedUser;
    }

    AppLogger.step('No cached identity found, signing in anonymously');
    final authResult = await _firebaseAuth.signInAnonymously();
    final uid = authResult.user?.uid;
    if (uid == null || uid.isEmpty) {
      AppLogger.error('Anonymous sign-in returned empty UID');
      throw Exception('Anonymous sign-in failed. Try again.');
    }
    AppLogger.success('Anonymous sign-in completed', data: uid);

    for (int attempt = 0; attempt < _maxCollisionRetries; attempt++) {
      final candidate = ShortCodeUtil.generateRawCode();
      AppLogger.step(
        'Generated short-code candidate',
        data: 'attempt=${attempt + 1}, code=$candidate',
      );
      final claimedUser = await _identityDataSource.claimShortCode(
        shortCode: candidate,
        uid: uid,
        fcmToken: '',
      );

      if (claimedUser != null) {
        await _localIdentityDataSource.saveUser(claimedUser);
        AppLogger.success(
          'Identity provisioned and persisted locally',
          data: claimedUser.shortCode,
        );
        return claimedUser;
      }
    }

    AppLogger.error('Identity provisioning exhausted collision retries');
    throw Exception('Could not assign a unique short code. Please retry.');
  }
}

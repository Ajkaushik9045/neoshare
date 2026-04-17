import '../../domain/entities/app_user.dart';
import '../../domain/repositories/identity_repo.dart';
import '../datasources/firestore_identity_ds.dart';

/// Concrete repository bridging identity data source and domain contract.
class IdentityRepoImpl implements IdentityRepo {
  IdentityRepoImpl(this._identityDataSource);

  final FirestoreIdentityDataSource _identityDataSource;

  @override
  Future<AppUser> provisionIdentity({required String displayName}) {
    return _identityDataSource.provisionUser(displayName: displayName);
  }
}

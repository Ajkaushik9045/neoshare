import '../entities/app_user.dart';
import '../repositories/identity_repo.dart';

/// Use case for creating or loading the local app identity.
class ProvisionIdentity {
  ProvisionIdentity(this._identityRepo);

  final IdentityRepo _identityRepo;

  Future<AppUser> call({required String displayName}) {
    return _identityRepo.provisionIdentity(displayName: displayName);
  }
}

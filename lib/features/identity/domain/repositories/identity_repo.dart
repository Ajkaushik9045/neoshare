import '../entities/app_user.dart';

/// Domain contract for identity management operations.
abstract class IdentityRepo {
  Future<AppUser> provisionIdentity({required String displayName});
}

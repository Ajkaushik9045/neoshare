part of 'identity_bloc.dart';

/// Identity presentation states.
sealed class IdentityState extends Equatable {
  const IdentityState();

  @override
  List<Object?> get props => [];
}

/// Initial pre-action state.
class IdentityInitial extends IdentityState {
  const IdentityInitial();
}

/// Loading state during provisioning workflow.
class IdentityLoading extends IdentityState {
  const IdentityLoading();
}

/// Success state carrying provisioned app user.
class IdentityReady extends IdentityState {
  const IdentityReady(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

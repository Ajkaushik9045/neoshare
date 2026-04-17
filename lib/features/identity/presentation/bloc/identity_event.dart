part of 'identity_bloc.dart';

/// Identity presentation events.
sealed class IdentityEvent extends Equatable {
  const IdentityEvent();

  @override
  List<Object?> get props => [];
}

/// Requests provisioning of a local/remote app identity.
class IdentityProvisionRequested extends IdentityEvent {
  const IdentityProvisionRequested();
}

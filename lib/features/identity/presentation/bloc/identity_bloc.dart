import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/usecases/provision_identity.dart';

part 'identity_event.dart';
part 'identity_state.dart';

/// BLoC orchestrating onboarding identity flow.
class IdentityBloc extends Bloc<IdentityEvent, IdentityState> {
  IdentityBloc(this._provisionIdentity) : super(const IdentityInitial()) {
    on<IdentityProvisionRequested>(_onProvisionRequested);
  }

  final ProvisionIdentity _provisionIdentity;

  Future<void> _onProvisionRequested(
    IdentityProvisionRequested event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    final user = await _provisionIdentity(displayName: event.displayName);
    emit(IdentityReady(user));
  }
}

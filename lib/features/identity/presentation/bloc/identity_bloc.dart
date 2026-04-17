import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/app_logger.dart';
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
    AppLogger.step('IdentityBloc received provisioning request');
    emit(const IdentityLoading());
    try {
      final user = await _provisionIdentity();
      AppLogger.success('IdentityBloc provisioning success', data: user.shortCode);
      emit(IdentityProvisioned(user));
    } catch (error, stackTrace) {
      AppLogger.error(
        'IdentityBloc provisioning failed',
        error: error,
        stackTrace: stackTrace,
      );
      emit(IdentityError(error.toString().replaceFirst('Exception: ', '')));
    }
  }
}

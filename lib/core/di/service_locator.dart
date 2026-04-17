import 'package:get_it/get_it.dart';

/// Global service locator for dependency registration and retrieval.
final GetIt sl = GetIt.instance;

/// Registers app dependencies.
///
/// In Phase 1 this stays intentionally lightweight. Feature-specific
/// registrations will be added in the next implementation phase.
Future<void> setupServiceLocator() async {}

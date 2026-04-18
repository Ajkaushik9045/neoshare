import 'package:go_router/go_router.dart';

import '../../features/identity/presentation/pages/onboarding_page.dart';
import '../../features/transfer/presentation/pages/send_page.dart';

/// Provides the GoRouter configuration for the application.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/send',
        builder: (context, state) => const SendPage(),
      ),
    ],
  );
}

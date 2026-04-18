import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/identity/presentation/pages/onboarding_page.dart';
import '../../features/transfer/presentation/pages/inbox_page.dart';
import '../../features/transfer/presentation/pages/send_page.dart';
import 'main_shell_page.dart';

// Private navigator keys for inner routers
final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _sendNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'send');
final GlobalKey<NavigatorState> _receiveNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'receive');

/// Provides the GoRouter configuration for the application
/// with a bottom navigation bar maintaining state.
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // Return the customizable UI shell wrapping the current branch
          return MainShellPage(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Home (Identity)
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const OnboardingPage(),
              ),
            ],
          ),
          // Branch 2: Send Phase
          StatefulShellBranch(
            navigatorKey: _sendNavigatorKey,
            routes: [
              GoRoute(
                path: '/send',
                builder: (context, state) => const SendPage(),
              ),
            ],
          ),
          // Branch 3: Receive (Inbox) Phase
          StatefulShellBranch(
            navigatorKey: _receiveNavigatorKey,
            routes: [
              GoRoute(
                path: '/receive',
                builder: (context, state) => const InboxPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

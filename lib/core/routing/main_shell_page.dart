import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The main shell page containing the bottom navigation bar.
class MainShellPage extends StatelessWidget {
  const MainShellPage({
    super.key,
    required this.navigationShell,
  });

  /// The navigation shell provided by [StatefulShellRoute].
  /// This maintains the state of each branch.
  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Navigate to the branch. This achieves the standard bottom navigation
    // behavior, retaining the state.
    navigationShell.goBranch(
      index,
      // Support navigating to the initial location when tapping the item that is
      // already active.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          backgroundColor: Colors.white,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFF3157E1)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.send_outlined),
              selectedIcon: Icon(Icons.send, color: Color(0xFF3157E1)),
              label: 'Send',
            ),
            NavigationDestination(
              icon: Icon(Icons.move_to_inbox_outlined),
              selectedIcon: Icon(Icons.move_to_inbox, color: Color(0xFF3157E1)),
              label: 'Receive',
            ),
          ],
        ),
      ),
    );
  }
}

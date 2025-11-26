import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../core/constants/app_constants.dart';

/// Main layout with left navigation bar
class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({
    super.key,
    required this.child,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isExpanded = false;
  // removed session-expired modal behavior

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    // No modal shown here; session-expired UI handled elsewhere or by route changes
    final themeProvider = context.watch<ThemeProvider>();
    final currentLocation = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Row(
        children: [
          // Left Navigation Bar
          NavigationRail(
            extended: _isExpanded,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primary.withOpacity(0.2),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            selectedIconTheme: IconThemeData(
              color: theme.colorScheme.primary,
              size: 28,
            ),
            unselectedIconTheme: IconThemeData(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            selectedLabelTextStyle: theme.textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            unselectedLabelTextStyle: theme.textTheme.labelLarge,
            selectedIndex: _getSelectedIndex(currentLocation),
            onDestinationSelected: (index) {
              _navigateToIndex(context, index);
            },
            leading: Column(
              children: [
                const SizedBox(height: 8),
                // App Logo/Title
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: _isExpanded
                      ? Row(
                          children: [
                            Icon(
                              Icons.waves,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppConstants.appName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          Icons.waves,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                ),
                const Divider(),
              ],
            ),
            trailing: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  // User Info - Collapsed
                  if (!_isExpanded)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              authProvider.username?.substring(0, 1).toUpperCase() ?? 'U',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            tooltip: 'Logout',
                            onPressed: () => _handleLogout(context),
                          ),
                        ],
                      ),
                    ),
                  // User Info - Expanded
                  if (_isExpanded)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary,
                                child: Text(
                                  authProvider.username?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    authProvider.username ?? 'User',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Logout Button
                          OutlinedButton.icon(
                            onPressed: () => _handleLogout(context),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Logout'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Theme Toggle Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.brightness_auto),
                                    tooltip: 'System Theme',
                                    color: themeProvider.themeMode ==
                                            ThemeMode.system
                                        ? theme.colorScheme.primary
                                        : null,
                                    onPressed: () => themeProvider
                                        .setThemeMode(ThemeMode.system),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.light_mode),
                                    tooltip: 'Light Theme',
                                    color: themeProvider.themeMode ==
                                            ThemeMode.light
                                        ? theme.colorScheme.primary
                                        : null,
                                    onPressed: () => themeProvider
                                        .setThemeMode(ThemeMode.light),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.dark_mode),
                                    tooltip: 'Dark Theme',
                                    color:
                                        themeProvider.themeMode == ThemeMode.dark
                                            ? theme.colorScheme.primary
                                            : null,
                                    onPressed: () => themeProvider
                                        .setThemeMode(ThemeMode.dark),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Toggle Button
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.chevron_left : Icons.chevron_right,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    tooltip: _isExpanded ? 'Collapse' : 'Expand',
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('DASHBOARD', style: TextStyle(fontSize: 14)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('SETTINGS', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),

          // Vertical Divider
          const VerticalDivider(thickness: 1, width: 1),

          // Main Content Area
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.contains('/dashboard')) return 0;
    if (location.contains('/settings')) return 1;
    return 0;
  }

  void _navigateToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/settings');
        break;
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}

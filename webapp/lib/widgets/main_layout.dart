import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../core/constants/app_constants.dart';

enum _UserMenuAction { systemTheme, lightTheme, darkTheme, logout }

/// Main layout with left navigation bar
class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // removed session-expired modal behavior

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentLocation = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Row(
        children: [
          // Left Navigation Bar
          NavigationRail(
            // Keep destinations pinned toward the top and user/menu at bottom.
            groupAlignment: -1.0,
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
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Icon(
                    Icons.waves,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
              ),
            ),
            trailing: Expanded( 
              child: Align(
                alignment: Alignment.bottomCenter,    
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      PopupMenuButton<_UserMenuAction>(
                        tooltip: 'Theme & logout',
                        position: PopupMenuPosition.over,
                        onSelected: (action) => _handleMenuSelection(
                          action,
                          themeProvider,
                          context,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _UserMenuAction.systemTheme,
                            child: _buildMenuRow(
                              theme,
                              icon: Icons.brightness_auto,
                              label: 'System theme',
                              selected: themeProvider.themeMode == ThemeMode.system,
                            ),
                          ),
                          PopupMenuItem(
                            value: _UserMenuAction.lightTheme,
                            child: _buildMenuRow(
                              theme,
                              icon: Icons.light_mode,
                              label: 'Light theme',
                              selected: themeProvider.themeMode == ThemeMode.light,
                            ),
                          ),
                          PopupMenuItem(
                            value: _UserMenuAction.darkTheme,
                            child: _buildMenuRow(
                              theme,
                              icon: Icons.dark_mode,
                              label: 'Dark theme',
                              selected: themeProvider.themeMode == ThemeMode.dark,
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: _UserMenuAction.logout,
                            child: _buildMenuRow(
                              theme,
                              icon: Icons.logout,
                              label: 'Logout',
                            ),
                          ),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                authProvider.username
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    'U',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              authProvider.username ?? 'User',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Tooltip(message: 'Dashboard', child: Icon(Icons.dashboard_outlined)),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('DASHBOARD', style: TextStyle(fontSize: 14)),
              ),
              NavigationRailDestination(
                icon: Tooltip(message: 'Settings', child: Icon(Icons.settings_outlined)),
                selectedIcon: Icon(Icons.settings),
                label: Text('SETTINGS', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),

          // Vertical Divider
          const VerticalDivider(thickness: 1, width: 1),

          // Main Content Area
          Expanded(child: widget.child),
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

  Future<void> _handleMenuSelection(
    _UserMenuAction action,
    ThemeProvider themeProvider,
    BuildContext context,
  ) async {
    switch (action) {
      case _UserMenuAction.systemTheme:
        themeProvider.setThemeMode(ThemeMode.system);
        break;
      case _UserMenuAction.lightTheme:
        themeProvider.setThemeMode(ThemeMode.light);
        break;
      case _UserMenuAction.darkTheme:
        themeProvider.setThemeMode(ThemeMode.dark);
        break;
      case _UserMenuAction.logout:
        await _handleLogout(context);
        break;
    }
  }

  Widget _buildMenuRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    bool selected = false,
  }) {
    final highlight = selected ? theme.colorScheme.primary : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: highlight),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: highlight,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (selected)
          Icon(
            Icons.check,
            size: 16,
            color: theme.colorScheme.primary,
          ),
      ],
    );
  }
}

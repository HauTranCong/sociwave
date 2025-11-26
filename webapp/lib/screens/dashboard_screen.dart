import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../providers/reels_provider.dart';
import '../providers/rules_provider.dart';
import '../providers/comments_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/monitor_provider.dart';
import '../data/services/monitoring_service.dart';
import '../providers/api_client_provider.dart';
import '../router/app_router.dart';
import '../widgets/reel_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_display.dart';
import '../widgets/stat_card.dart';

/// Main dashboard screen showing reels and monitoring status
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule loading after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    // Wait for AuthProvider to finish initialization and provide a token
    final authProvider = context.read<AuthProvider>();
    final timeout = DateTime.now().add(const Duration(seconds: 10));
    while (authProvider.isInitializing && DateTime.now().isBefore(timeout)) {
      // small delay while waiting for AuthProvider to load stored auth
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // If not authenticated after waiting, abort loading to avoid unauthenticated requests
    if (!authProvider.isAuthenticated) {
      // Auth not ready — skip loading data for now. Dashboard will update once user logs in.
      return;
    }

    final configProvider = context.read<ConfigProvider>();
    final reelsProvider = context.read<ReelsProvider>();
    final commentsProvider = context.read<CommentsProvider>();
    final rulesProvider = context.read<RulesProvider>();

    // Test API connection if not using mock data
    if (!configProvider.config.useMockData) {
      await configProvider.testConnection();
    }

    // Initialize API-dependent providers with config
    reelsProvider.initialize(configProvider.config);
    commentsProvider.initialize(configProvider.config);

    await Future.wait([reelsProvider.fetchReels(), rulesProvider.loadRules()]);
  }

  Future<void> _refreshData() async {
    final reelsProvider = context.read<ReelsProvider>();
    await reelsProvider.refreshReels();

    if (!mounted) return;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${reelsProvider.reels.length} reels'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: const Text('Dashboard'),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Show config status
          Consumer<ConfigProvider>(
            builder: (context, config, _) {
              final isUsingMockData = config.config.useMockData;
              final isConnected = config.isConnected;
              final isTestingConnection = config.isTestingConnection;

              // Determine icon and color based on connection status
              IconData icon;
              Color color;
              String tooltip;

              if (isUsingMockData) {
                icon = Icons.cloud_off;
                color = Colors.orange;
                tooltip = 'Using Mock Data';
              } else if (isTestingConnection) {
                icon = Icons.cloud_sync;
                color = Colors.blue;
                tooltip = 'Testing Connection...';
              } else if (isConnected) {
                icon = Icons.cloud_done;
                color = Colors.green;
                tooltip = 'Connected: ${config.config.pageId}';
              } else {
                icon = Icons.cloud_off;
                color = Colors.red;
                tooltip =
                    'Disconnected: ${config.config.pageId} (API not connected)';
              }

              return IconButton(
                icon: Icon(icon, color: color),
                tooltip: tooltip,
                onPressed: () => context.go(AppRouter.settings),
              );
            },
          ),
          // Refresh Button
          Consumer<ReelsProvider>(
            builder: (context, reelsProvider, _) {
              return IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: reelsProvider.isLoading
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Refresh All Reels',
                onPressed: reelsProvider.isLoading ? null : _refreshData,
              );
            },
          ),
          Padding(padding: const EdgeInsets.only(right: 8)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // API Configuration Banner (if using mock data)
            SliverToBoxAdapter(child: _buildConfigBanner()),

            // Statistics Header
            SliverToBoxAdapter(child: _buildStatisticsSection()),

            // Monitoring Status
            SliverToBoxAdapter(child: _buildMonitoringSection()),

            // Reels List Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Reels',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Consumer<ReelsProvider>(
                      builder: (context, provider, child) {
                        return Text(
                          '${provider.reels.length} reels',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Reels List
            Consumer<ReelsProvider>(
              builder: (context, reelsProvider, child) {
                if (reelsProvider.isLoading) {
                  return const SliverFillRemaining(
                    child: LoadingIndicator(message: 'Loading reels...'),
                  );
                }

                if (reelsProvider.error != null) {
                  return SliverFillRemaining(
                    child: ErrorDisplay(
                      message: reelsProvider.error!,
                      onRetry: _loadData,
                    ),
                  );
                }

                if (reelsProvider.reels.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.video_library_outlined,
                      title: 'No Reels Found',
                      message:
                          'Click the refresh button to load your Facebook reels.\n\nMake sure mock data is disabled in Settings.',
                      actionLabel: 'Load Reels',
                      onAction: _refreshData,
                    ),
                  );
                }

                // Display in list view for better card visibility
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final reel = reelsProvider.reels[index];
                      return ReelCard(
                        reel: reel,
                        onTap: () {
                          context.push(
                            AppRouter.comments,
                            extra: {
                              'reelId': reel.id,
                              'reelDescription': reel.description,
                            },
                          );
                        },
                        onEditRule: () {
                          context.push(
                            AppRouter.ruleEditor,
                            extra: {
                              'reelId': reel.id,
                              'reelDescription': reel.description,
                            },
                          );
                        },
                      );
                    }, childCount: reelsProvider.reels.length),
                  ),
                );
              },
            ),

            // Bottom Spacing
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigBanner() {
    return Consumer<ConfigProvider>(
      builder: (context, config, _) {
        // Only show banner if using mock data
        if (!config.config.useMockData) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            border: Border.all(color: Colors.orange, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Using Mock Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Turn off mock data in Settings to load real Facebook reels.',
                      style: TextStyle(fontSize: 14, color: Colors.orange[800]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => context.go(AppRouter.settings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsSection() {
    return Consumer3<RulesProvider, ReelsProvider, ConfigProvider>(
      builder: (context, rulesProvider, reelsProvider, configProvider, child) {
        final pageId = configProvider.config.pageId;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => context.go(AppRouter.settings),
                  child: StatCard(
                    icon: Icons.person,
                    title: 'Page Profile',
                    value: pageId.isNotEmpty ? pageId : 'Not set',
                    subtitle: 'Manage pages & profiles',
                    color: Colors.orange,
                  ),
                ),
              ),
              Expanded(
                child: StatCard(
                  icon: Icons.rule,
                  title: 'Active Rules',
                  value: '${rulesProvider.enabledRuleCount}',
                  subtitle: 'of ${rulesProvider.ruleCount} total',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.video_library,
                  title: 'Reels Loaded',
                  value: '${reelsProvider.reels.length}',
                  subtitle: 'from Facebook / cache',
                  color: Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonitoringSection() {
    return Consumer<MonitorProvider>(
      builder: (context, provider, child) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          provider.isRunning
                              ? Icons.play_circle
                              : Icons.pause_circle,
                          color: provider.isRunning
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Background Monitoring',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Switch(
                      value: provider.isRunning,
                      onChanged: (value) async {
                        if (value) {
                          await provider.startMonitoring();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Monitoring started'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          await provider.stopMonitoring();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Monitoring stopped'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Status text with detailed information
                _buildStatusText(provider),
                const SizedBox(height: 8),
                // Interval information with edit button
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Check interval: ${provider.intervalText}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showIntervalDialog(context, provider),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Format timestamp to readable format
  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final year = timestamp.year;

    return '$year-$month-$day $hour:$minute:$second';
  }

  /// Convert a duration to a friendly "time ago" string
  String _formatDurationAgo(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else if (duration.inHours < 24) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    } else {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
  }

  String _friendlyMonitorError(String error) {
    final lowerCaseError = error.toLowerCase();
    if (lowerCaseError.contains('not authenticated') ||
        lowerCaseError.contains('statuscode: 401') ||
        lowerCaseError.contains('unauthorized')) {
      return 'Authentication failed. Please sign in again from Settings.';
    }
    if (lowerCaseError.contains('expired')) {
      return 'Access token expired. Please refresh your credentials.';
    }
    if (lowerCaseError.contains('rate limit')) {
      return 'API rate limit exceeded. Monitoring will retry automatically.';
    }
    return error;
  }

  /// Build detailed status text
  Widget _buildStatusText(MonitorProvider provider) {
    final textTheme = Theme.of(context).textTheme;
    final hasRecentError = provider.status.hasRecentError;
    final lastError = provider.lastError;
    final lastCheck = provider.lastCheck;

    IconData icon;
    Color statusColor;
    String primaryText;
    String? secondaryText;

    if (hasRecentError && lastError != null) {
      icon = Icons.error_outline;
      statusColor = Colors.red[700]!;
      var friendlyError = _friendlyMonitorError(lastError);
      if (!friendlyError.toLowerCase().startsWith('error')) {
        friendlyError = 'Error: $friendlyError';
      }
      primaryText = friendlyError;
      secondaryText = 'Monitoring is paused until the issue is resolved.';
    } else if (!provider.isRunning) {
      icon = Icons.info_outline;
      statusColor = Colors.grey[600]!;
      primaryText = 'Monitoring is stopped';
      secondaryText = 'Enable the switch to resume automatic checks.';
    } else if (lastCheck == null) {
      icon = Icons.hourglass_empty;
      statusColor = Colors.blue[700]!;
      primaryText = 'Starting monitoring...';
      secondaryText = 'Waiting for the first check to complete.';
    } else {
      icon = Icons.check_circle_outline;
      statusColor = Colors.green[700]!;
      final formattedTimestamp = _formatTimestamp(lastCheck);
      final elapsed = _formatDurationAgo(
        DateTime.now().difference(lastCheck),
      );
      primaryText = 'Monitoring active';
      secondaryText = 'Last check $formattedTimestamp ($elapsed ago)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: statusColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                primaryText,
                style: textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (secondaryText != null)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              secondaryText,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// Show dialog to change monitoring interval
  void _showIntervalDialog(BuildContext context, MonitorProvider provider) {
    final TextEditingController controller = TextEditingController(
      text: provider.monitoringInterval.inMinutes.toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Check Interval'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the monitoring interval in minutes:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Interval (minutes)',
                  hintText: 'Minimum 1 minute',
                  prefixIcon: Icon(Icons.timer),
                  border: OutlineInputBorder(),
                  helperText: 'Min: 1 minute',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  final minutes = int.tryParse(value);
                  if (minutes == null) {
                    return 'Please enter a valid number';
                  }
                  if (minutes < 1) {
                    return 'Minimum interval is 1 minute';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
              ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final minutes = int.parse(controller.text);
                final seconds = minutes * 60;

                // Call backend to set monitoring interval
                bool backendOk = false;
                try {
                  final apiClient = context.read<ApiClientProvider>().client;
                  final monitoringService = MonitoringService(apiClient);
                  final updated = await monitoringService.setMonitoringInterval(seconds);
                  backendOk = updated != null;
                } catch (e) {
                  backendOk = false;
                }

                if (!mounted) return;

                Navigator.pop(context);

                if (backendOk) {
                  // Update local provider interval as well
                  final success = await provider.setIntervalMinutes(minutes);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Interval updated to ${provider.intervalText}'
                              : 'Backend updated — local update failed',
                        ),
                        backgroundColor: success ? Colors.green : Colors.orange,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update interval on server'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

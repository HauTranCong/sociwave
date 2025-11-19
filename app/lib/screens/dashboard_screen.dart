import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../providers/reels_provider.dart';
import '../providers/rules_provider.dart';
import '../providers/comments_provider.dart';
import '../providers/monitor_provider.dart';
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
    
    final configProvider = context.read<ConfigProvider>();
    final reelsProvider = context.read<ReelsProvider>();
    final commentsProvider = context.read<CommentsProvider>();
    final rulesProvider = context.read<RulesProvider>();
    
    // Initialize API-dependent providers with config
    reelsProvider.initialize(configProvider.config);
    commentsProvider.initialize(configProvider.config);
    
    await Future.wait([
      reelsProvider.fetchReels(),
      rulesProvider.loadRules(),
    ]);
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
              return IconButton(
                icon: Icon(
                    config.config.useMockData ? Icons.cloud_off : Icons.cloud_done,
                  color: config.config.useMockData ? Colors.orange : Colors.green,
                ),
                tooltip: config.config.useMockData 
                    ? 'Using Mock Data' 
                    : 'Using Real API: ${config.config.pageId}',
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
          Padding(padding:  const EdgeInsets.only(right: 8)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // API Configuration Banner (if using mock data)
            SliverToBoxAdapter(
              child: _buildConfigBanner(),
            ),

            // Statistics Header
            SliverToBoxAdapter(
              child: _buildStatisticsSection(),
            ),

            // Monitoring Status
            SliverToBoxAdapter(
              child: _buildMonitoringSection(),
            ),

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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
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
                      message: 'Click the refresh button to load your Facebook reels.\n\nMake sure mock data is disabled in Settings.',
                      actionLabel: 'Load Reels',
                      onAction: _refreshData,
                    ),
                  );
                }

                // Display in list view for better card visibility
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                      },
                      childCount: reelsProvider.reels.length,
                    ),
                  ),
                );
              },
            ),

            // Bottom Spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
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
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 32),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[800],
                      ),
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
    return Consumer2<RulesProvider, MonitorProvider>(
      builder: (context, rulesProvider, monitorProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
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
                  icon: Icons.check_circle,
                  title: 'Total Checks',
                  value: '${monitorProvider.totalChecks}',
                  subtitle: 'monitoring cycles',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.reply,
                  title: 'Auto Replies',
                  value: '${monitorProvider.totalReplies}',
                  subtitle: 'sent',
                  color: Colors.orange,
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
                Text(
                  provider.getStatusText(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (provider.lastCheck != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last checked: ${_formatLastCheck(provider.lastCheck!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatLastCheck(DateTime lastCheck) {
    final now = DateTime.now();
    final difference = now.difference(lastCheck);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

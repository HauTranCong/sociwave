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
import '../widgets/monitoring_metrics_widget.dart';

/// Main dashboard screen showing reels and monitoring status
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSwitchingPage = false;
  bool _isPageLoading = false;
  String? _selectedPageId;

  @override
  void initState() {
    super.initState();
    // Schedule loading after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Widget _buildStatisticsRow({
    required RulesProvider rulesProvider,
    required ReelsProvider reelsProvider,
    ConfigProvider? configProvider,
    String? pageId,
    String? pageLabel,
  }) {
    final finalPageId = pageId ?? configProvider?.config.pageId ?? '';
    final finalPageLabel =
        pageLabel ??
        (configProvider != null
            ? configProvider.pageLabel(finalPageId)
            : finalPageId);

    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.person,
            title: 'Name',
            value: finalPageLabel.isNotEmpty ? finalPageLabel : 'Not set',
            subtitle: finalPageId.isNotEmpty
                ? 'ID: $finalPageId'
                : 'No page selected',
            color: Colors.orange,
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
    );
  }

  Widget _buildReelsSection(
    ReelsProvider reelsProvider, {
    required String pageId,
    BuildContext? navContext,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Reels',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${reelsProvider.reels.length} reels',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (reelsProvider.isLoading)
          const LoadingIndicator(message: 'Loading reels...')
        else if (reelsProvider.error != null)
          ErrorDisplay(message: reelsProvider.error!, onRetry: _loadData)
        else if (reelsProvider.reels.isEmpty)
          EmptyState(
            icon: Icons.video_library_outlined,
            title: 'No Reels Found',
            message:
                'Click the refresh button to load your Facebook reels.\n\nMake sure mock data is disabled in Settings.',
            actionLabel: 'Load Reels',
            onAction: _refreshData,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reelsProvider.reels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reel = reelsProvider.reels[index];
              return ReelCard(
                key: ValueKey(reel.id),
                index: index + 1,
                reel: reel,
                onTap: () {
                  // Ensure API client is scoped to the current page before navigating
                  context.read<ApiClientProvider>().setPageId(pageId);

                  final parentCtx = navContext ?? context;
                  // Close the bottom sheet then navigate from the parent
                  // context in a safe, post-frame callback.
                  Navigator.of(context).maybePop().then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      try {
                        GoRouter.of(parentCtx).push(
                          AppRouter.comments,
                          extra: {
                            'reelId': reel.id,
                            'reelDescription': reel.description,
                            'pageId': pageId,
                          },
                        );
                      } catch (e, st) {
                        debugPrint('navigation after pop failed: $e\n$st');
                      }
                    });
                  });
                },
                onEditRule: () {
                  final parentCtx = navContext ?? context;
                  Navigator.of(context).maybePop().then((_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      try {
                        GoRouter.of(parentCtx).push(
                          AppRouter.ruleEditor,
                          extra: {
                            'reelId': reel.id,
                            'reelDescription': reel.description,
                            'pageId': pageId,
                          },
                        );
                      } catch (e, st) {
                        debugPrint('navigation after pop failed: $e\n$st');
                      }
                    });
                  });
                },
              );
            },
          ),
      ],
    );
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
    if (!configProvider.config.useMockData) {
      await configProvider.testAllPagesConnection();

      // Ensure per-page configuration state is loaded at startup so the
      // dashboard can show correct "Configured" badges without requiring
      // the user to open a page. Fetch configs sequentially to avoid
      // overwhelming the backend on slow connections.
      for (final pageId in configProvider.managedPages) {
        try {
          await configProvider.getConfigForPage(pageId);
        } catch (e) {
          // ignore individual page failures — connection status is still useful
        }
      }
    }
  }

  // Previously there was logic to switch the global selected page. That behavior
  // has been removed; per-page operations now use explicit per-page APIs.

  Future<void> _refreshData() async {
    final apiClientProvider = context.read<ApiClientProvider>();
    final pageId = _selectedPageId ?? apiClientProvider.client.pageId;
    if (pageId == null || pageId.isEmpty) {
      return;
    }

    final reelsProvider = context.read<ReelsProvider>();
    await _withPageScope(pageId, () => reelsProvider.refreshReels());

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
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // API Configuration Banner (if using mock data)
            SliverToBoxAdapter(child: _buildConfigBanner()),

            SliverToBoxAdapter(child: MonitoringMetricsWidget()),

            // Page selector cards or inline detail
            SliverToBoxAdapter(
              child: _selectedPageId == null
                  ? _buildPageCardsSection()
                  : _buildPageDetailSection(_selectedPageId!),
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

  Widget _buildPageCardsSection() {
    return Consumer<ConfigProvider>(
      builder: (context, provider, _) {
        final pages = provider.managedPages;
        if (pages.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSwitchingPage) const LinearProgressIndicator(minHeight: 2),
              if (_isSwitchingPage) const SizedBox(height: 6),
              ...pages.map(
                (pageId) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildPageCard(provider, pageId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageDetailSection(String pageId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isPageLoading ? 0.6 : 1,
        child: SizedBox(
          width: double.infinity,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.withOpacity(0.25), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back to pages',
                        onPressed: _isPageLoading ? null : _exitPageDetail,
                      ),
                      const SizedBox(width: 8),
                      Consumer<ConfigProvider>(
                        builder: (context, configProvider, _) {
                          final label = configProvider.pageLabel(pageId);
                          return Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'ID: $pageId',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isPageLoading) ...[
                    const LoadingIndicator(message: 'Loading page...'),
                  ] else
                    Consumer3<RulesProvider, ReelsProvider, ConfigProvider>(
                      builder:
                          (
                            context,
                            rulesProvider,
                            reelsProvider,
                            configProvider,
                            _,
                          ) {
                            final label = configProvider.pageLabel(pageId);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatisticsRow(
                                  rulesProvider: rulesProvider,
                                  reelsProvider: reelsProvider,
                                  pageId: pageId,
                                  pageLabel: label,
                                ),
                                const SizedBox(height: 16),
                                _buildMonitoringSection(
                                  margin: EdgeInsets.zero,
                                  pageId: pageId,
                                ),
                                const SizedBox(height: 16),
                                _buildReelsSection(
                                  reelsProvider,
                                  pageId: pageId,
                                ),
                              ],
                            );
                          },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPageDetailsInline(String pageId) async {
    if (_isSwitchingPage || _isPageLoading) return;

    setState(() {
      _selectedPageId = pageId;
      _isPageLoading = true;
    });

    final configProvider = context.read<ConfigProvider>();
    final reelsProvider = context.read<ReelsProvider>();
    final rulesProvider = context.read<RulesProvider>();
    final commentsProvider = context.read<CommentsProvider>();

    try {
      final pageConfig = await configProvider.getConfigForPage(pageId);
      if (pageConfig != null) {
        reelsProvider.initialize(pageConfig);
        commentsProvider.initialize(pageConfig);
      }

      await _withPageScope(
        pageId,
        () => Future.wait([
          reelsProvider.fetchReels(forceRefresh: true),
          rulesProvider.loadRules(),
        ]),
      );
    } catch (e, st) {
      debugPrint('[_openPageDetailsInline] fetch error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load page details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  void _exitPageDetail() {
    setState(() {
      _selectedPageId = null;
      _isPageLoading = false;
    });
  }

  /// Run an async action scoped to a specific page on the shared ApiClient.
  Future<T> _withPageScope<T>(
    String pageId,
    Future<T> Function() action,
  ) async {
    final apiClientProvider = context.read<ApiClientProvider>();
    final originalPage = apiClientProvider.client.pageId;
    try {
      apiClientProvider.setPageId(pageId);
      return await action();
    } finally {
      apiClientProvider.setPageId(originalPage);
    }
  }

  Widget _buildPageCard(ConfigProvider provider, String pageId) {
    final theme = Theme.of(context);
    final isConfigured = provider.isPageConfigured(pageId);
    final isConnected = provider.isPageConnected(pageId);
    final pageLabel = provider.pageLabel(pageId);
    final borderColor = Colors.grey.withOpacity(
      theme.brightness == Brightness.dark ? 0.45 : 0.25,
    );
    final iconColor = isConnected ? Colors.green : Colors.grey.withOpacity(0.8);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isSwitchingPage ? 0.6 : 1,
      child: SizedBox(
        width: double.infinity,
        child: Card(
          key: ValueKey('page_card_$pageId'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor, width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isSwitchingPage
                ? null
                : () => _openPageDetailsInline(pageId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pageLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => context.go(
                              AppRouter.settings,
                              extra: {'pageId': pageId},
                            ),
                            child: const Text('Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          isConfigured ? 'Configured' : 'Missing config',
                        ),
                        backgroundColor: isConfigured
                            ? Colors.green.withOpacity(0.15)
                            : Colors.orangeAccent.withOpacity(0.15),
                        labelStyle: theme.textTheme.bodySmall?.copyWith(
                          color: isConfigured
                              ? Colors.green
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          isConnected ? 'Connected' : 'Not Connected',
                        ),
                        backgroundColor: isConnected
                            ? Colors.green.withOpacity(0.15)
                            : Colors.orangeAccent.withOpacity(0.15),
                        labelStyle: theme.textTheme.bodySmall?.copyWith(
                          color: isConnected
                              ? Colors.green
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringSection({EdgeInsets? margin, required String pageId}) {
    return Consumer<MonitorProvider>(
      builder: (context, provider, child) {
        // Ensure monitoring API calls are scoped to the current page
        provider.setPageScope(pageId);
        return Card(
          margin:
              margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      onTap: () =>
                          _showIntervalDialog(context, provider, pageId),
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
    String secondaryText;

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
      final elapsed = _formatDurationAgo(DateTime.now().difference(lastCheck));
      primaryText = 'Monitoring active';
      secondaryText = 'Last check $formattedTimestamp ($elapsed ago)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: statusColor),
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
  void _showIntervalDialog(
    BuildContext context,
    MonitorProvider provider,
    String pageId,
  ) {
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

                if (pageId.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select a page before updating interval.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Call backend to set monitoring interval (scoped to page)
                bool backendOk = false;
                try {
                  final apiClientProvider = context.read<ApiClientProvider>();
                  apiClientProvider.setPageId(pageId);
                  final monitoringService = MonitoringService(
                    apiClientProvider.client,
                  );
                  final updated = await monitoringService.setMonitoringInterval(
                    seconds,
                  );
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

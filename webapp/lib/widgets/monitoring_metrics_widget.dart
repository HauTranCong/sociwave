import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../providers/api_client_provider.dart';
import 'dart:async';

class MonitoringMetricsWidget extends StatefulWidget {
  const MonitoringMetricsWidget({super.key});

  @override
  State<MonitoringMetricsWidget> createState() => _MonitoringMetricsWidgetState();
}

class _MonitoringMetricsWidgetState extends State<MonitoringMetricsWidget> {
  bool _loading = true;
  // metrics list not needed for summary card; keep aggregate only
  String? _error;
  Map<String, dynamic>? _aggregate;
  Timer? _pollTimer;
  bool _lastFetchSuccess = true;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
    // poll every 2 minutes to keep aggregates fresh
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => _fetchMetrics());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMetrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apiClientProvider = Provider.of<ApiClientProvider>(context, listen: false);
      final apiClient = apiClientProvider.client;
  // fetch aggregate totals directly (we only show aggregates in this card)
  await apiClient.getMonitoringMetrics(limit: 10); // keep call to refresh backend cache if needed
  // fetch aggregate totals too
      Map<String, dynamic>? aggregate;
      try {
        aggregate = await apiClient.getAggregateMetrics();
      } catch (_) {
        aggregate = null;
      }
      setState(() {
        _aggregate = aggregate;
        _loading = false;
        _lastFetchSuccess = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
        _lastFetchSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always render the card immediately. Load metrics in background
    // and show inline loading state / errors inside the expanded area.

    // Calculate throughput (api calls per second) if we have aggregate and duration
    String throughputText = 'N/A';
    if (_aggregate != null) {
      final apiCalls = (_aggregate!['api_calls'] ?? 0) as num;
      final duration = (_aggregate!['duration_seconds'] ?? 0) as num;
      if (duration > 0) {
        final t = apiCalls / duration;
        throughputText = t.toStringAsFixed(2) + ' calls/sec';
      }
    }

  // Build modern metric tiles (icon + big value + label)
  final reelsActive = _aggregate != null ? (_aggregate!['reels_active'] ?? _aggregate!['reels_scanned']) : null;
  final commentsScanned = _aggregate != null ? (_aggregate!['comments_scanned'] ?? null) : null;
  final apiCalls = _aggregate != null ? (_aggregate!['api_calls'] ?? null) : null;
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

    Widget metricTile(IconData icon, String label, String value, {Color? color}) {
      final tileColor = color ?? cs.primary;
      return Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          border: Border.all(color: Colors.grey.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tileColor.withOpacity(0.12),
              radius: 20,
              child: Icon(icon, color: tileColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final metricTiles = <Widget>[
      metricTile(Icons.play_circle_fill, 'Reels active', reelsActive != null ? reelsActive.toString() : 'N/A'),
      metricTile(Icons.comment, 'Comments scanned', commentsScanned != null ? commentsScanned.toString() : 'N/A', color: cs.secondary),
      metricTile(Icons.reply, 'Replied', _aggregate != null ? (_aggregate!['replies_sent'] ?? '0').toString() : 'N/A', color: Colors.green),
      metricTile(Icons.inbox, 'Inbox sent', _aggregate != null ? (_aggregate!['inbox_sent'] ?? '0').toString() : 'N/A', color: Colors.purple),
      metricTile(Icons.api, 'API calls', apiCalls != null ? apiCalls.toString() : 'N/A', color: cs.primary),
      metricTile(Icons.speed, 'API throughput', throughputText, color: cs.onSurface.withOpacity(0.6)),
    ];

    final borderColor = Colors.grey.withOpacity(
      cs.brightness == Brightness.dark ? 0.45 : 0.25,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          const SizedBox(height: 8), // match per-card top spacing used by page cards
          SizedBox(
            width: double.infinity,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart, size: 28),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Monitoring Metrics', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        // Live / Offline indicator with animation
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                          child: _lastFetchSuccess
                              ? Row(key: const ValueKey('live'), children: [
                                  // pulsing green dot
                                  _PulsingDot(color: cs.secondary),
                                  const SizedBox(width: 6),
                                  Text('Live', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green)),
                                ])
                              : Row(key: const ValueKey('offline'), children: [
                                  Icon(Icons.cloud_off, color: Colors.grey.shade600, size: 18),
                                  const SizedBox(width: 6),
                                  Text('Offline', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                                ]),
                        ),
                        const SizedBox(width: 8),
                        // inline spinner for background refresh / manual refresh
                        if (_loading)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0))
                        // else
                          // IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _fetchMetrics),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
                      ),
                    // modern metric tiles: responsive grid-like layout with fixed column widths
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 6.0),
                      child: LayoutBuilder(builder: (context, constraints) {
                        // Choose column count based on available width (best-practice responsive breakpoints)
                        final maxWidth = constraints.maxWidth;
                        final int columns = maxWidth < 520 ? 1 : (maxWidth < 960 ? 2 : 3);
                        final double gap = 12.0;
                        final double totalGap = gap * (columns - 1);
                        final double itemWidth = (maxWidth - totalGap) / columns;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: metricTiles
                              .map((w) => SizedBox(width: itemWidth, child: w))
                              .toList(),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// chart removed: this widget renders aggregated metrics only


class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 8, spreadRadius: 1)]),
      ),
    );
  }
}

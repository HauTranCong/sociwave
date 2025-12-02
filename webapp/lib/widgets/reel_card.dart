import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models/reel.dart';
import '../providers/rules_provider.dart';

/// Card widget for displaying a reel with rule status
class ReelCard extends StatelessWidget {
  final Reel reel;
  final VoidCallback onTap;
  final VoidCallback onEditRule;
  final int? index;

  const ReelCard({
    super.key,
    required this.reel,
    required this.onTap,
    required this.onEditRule,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        index.toString(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      // Video Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.video_library,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Reel Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reel.displayTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reel.relativeTime,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 40),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Rule Info and Actions
                  Consumer<RulesProvider>(
                    builder: (context, rulesProvider, child) {
                      final rule = rulesProvider.getRule(reel.id);

                      if (rule == null) {
                        return _buildNoRuleSection(context);
                      }

                      return _buildRuleSection(context, rule);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRuleSection(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No auto-reply rule set',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        TextButton.icon(
          onPressed: onEditRule,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Rule'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleSection(BuildContext context, rule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Keywords: ${rule.keywordsSummary}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: onEditRule,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<RulesProvider>(
              builder: (context, rulesProvider, child) {
                return ElevatedButton.icon(
                  onPressed: () async {
                    await rulesProvider.toggleRule(reel.id);
                  },
                  icon: Icon(
                    rule.enabled ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(rule.enabled ? 'Pause' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: rule.enabled
                        ? Colors.orange
                        : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

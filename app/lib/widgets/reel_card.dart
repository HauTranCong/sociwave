import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/models/reel.dart';
import '../providers/rules_provider.dart';

/// Card widget for displaying a reel with rule status
class ReelCard extends StatelessWidget {
  final Reel reel;
  final VoidCallback onTap;
  final VoidCallback onEditRule;

  const ReelCard({
    super.key,
    required this.reel,
    required this.onTap,
    required this.onEditRule,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.video_library,
                      color: Theme.of(context).colorScheme.primary,
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reel.relativeTime,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Rule Status Badge
                  _buildRuleStatusBadge(context),
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
    );
  }

  Widget _buildRuleStatusBadge(BuildContext context) {
    if (!reel.hasRule) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No Rule',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: reel.ruleEnabled ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reel.ruleEnabled ? Icons.check_circle : Icons.pause_circle,
            size: 14,
            color: reel.ruleEnabled ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 4),
          Text(
            reel.ruleEnabled ? 'Active' : 'Paused',
            style: TextStyle(
              fontSize: 12,
              color: reel.ruleEnabled ? Colors.green[700] : Colors.orange[700],
              fontWeight: FontWeight.w600,
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
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
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../domain/models/rule.dart';
import '../providers/rules_provider.dart';
import '../providers/reels_provider.dart';
import '../widgets/loading_overlay.dart';

/// Screen for creating/editing auto-reply rules
class RuleEditorScreen extends StatefulWidget {
  final String? reelId;
  final String? reelDescription;

  const RuleEditorScreen({super.key, this.reelId, this.reelDescription});

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _keywordsController;
  late TextEditingController _replyMessageController;
  late TextEditingController _inboxMessageController;
  bool _enabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingRule();
  }

  void _loadExistingRule() {
    if (widget.reelId != null) {
      final rulesProvider = context.read<RulesProvider>();
      final rule = rulesProvider.getRule(widget.reelId!);

      if (rule != null) {
        _keywordsController = TextEditingController(
          text: rule.matchWords.join(', '),
        );
        _replyMessageController = TextEditingController(
          text: rule.replyMessage,
        );
        _inboxMessageController = TextEditingController(
          text: rule.inboxMessage ?? '',
        );
        _enabled = rule.enabled;
      } else {
        _keywordsController = TextEditingController();
        _replyMessageController = TextEditingController();
        _inboxMessageController = TextEditingController();
      }
    } else {
      _keywordsController = TextEditingController();
      _replyMessageController = TextEditingController();
      _inboxMessageController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _keywordsController.dispose();
    _replyMessageController.dispose();
    _inboxMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.reelId == null) return;

    setState(() => _isLoading = true);

    // Parse keywords
    final keywords = _keywordsController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    // Create rule
    final inboxMessage = _inboxMessageController.text.trim();
    final rule = Rule(
      objectId: widget.reelId!,
      matchWords: keywords,
      replyMessage: _replyMessageController.text.trim(),
      inboxMessage: inboxMessage.isEmpty ? null : inboxMessage,
      enabled: _enabled,
    );

    final rulesProvider = context.read<RulesProvider>();
    final success = await rulesProvider.saveRule(rule);

    if (!mounted) return;

    if (success) {
      // Update reel's rule status
      context.read<ReelsProvider>().updateReelRuleStatus(
        widget.reelId!,
        hasRule: true,
        enabled: _enabled,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rule saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Go back
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save rule'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteRule() async {
    if (widget.reelId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final rulesProvider = context.read<RulesProvider>();
    final success = await rulesProvider.deleteRule(widget.reelId!);

    if (!mounted) return;

    if (success) {
      // Update reel's rule status
      context.read<ReelsProvider>().updateReelRuleStatus(
        widget.reelId!,
        hasRule: false,
        enabled: false,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rule deleted')));

      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete rule'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRule = widget.reelId != null &&
        context.watch<RulesProvider>().hasRule(widget.reelId!);

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Back',
                            onPressed: () => context.pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Rule',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (widget.reelDescription != null)
                                  Text(
                                    widget.reelDescription!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (hasRule)
                            TextButton.icon(
                              onPressed: _isLoading ? null : _deleteRule,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Reel Info Card
                            if (widget.reelDescription != null)
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reel',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.reelDescription!,
                                        style: theme.textTheme.bodyMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),

                            // Keywords Field
                            TextFormField(
                              controller: _keywordsController,
                              decoration: const InputDecoration(
                                labelText: 'Keywords',
                                hintText: 'hello, hi, thanks (comma-separated)',
                                helperText:
                                    'Enter keywords to match. Use "." to match all comments.',
                                prefixIcon: Icon(Icons.label),
                              ),
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'At least one keyword is required (or use "." for all)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Reply Message Field
                            TextFormField(
                              controller: _replyMessageController,
                              decoration: const InputDecoration(
                                labelText: 'Reply Message',
                                hintText: 'Thank you for your comment!',
                                helperText:
                                    'This message will be posted as a reply',
                                prefixIcon: Icon(Icons.message),
                              ),
                              maxLines: 4,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Reply message is required';
                                }
                                if (value.trim().length < 3) {
                                  return 'Reply message is too short';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Private Reply Field (Optional)
                            TextFormField(
                              controller: _inboxMessageController,
                              decoration: const InputDecoration(
                                labelText: 'Private Reply (Optional)',
                                hintText:
                                    'Send a private message to the commenter...',
                                helperText:
                                    'This private message will be sent to the user\'s Messenger after replying',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              maxLines: 4,
                              validator: (value) {
                                if (value != null &&
                                    value.trim().isNotEmpty &&
                                    value.trim().length < 3) {
                                  return 'Private reply is too short';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Enable Switch
                            Card(
                              margin: EdgeInsets.zero,
                              child: SwitchListTile(
                                title: const Text('Enable Auto-Reply'),
                                subtitle: const Text(
                                  'Automatically reply to matching comments',
                                ),
                                value: _enabled,
                                onChanged: (value) {
                                  setState(() => _enabled = value);
                                },
                                secondary: Icon(
                                  _enabled ? Icons.check_circle : Icons.cancel,
                                  color: _enabled ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Save Button
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveRule,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Rule'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

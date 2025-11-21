import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/comments_provider.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_display.dart';
import '../widgets/comment_card.dart';

/// Screen for viewing and replying to comments
class CommentsScreen extends StatefulWidget {
  final String reelId;
  final String reelDescription;

  const CommentsScreen({
    super.key,
    required this.reelId,
    required this.reelDescription,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(seconds: 60); // Auto-refresh every 30 seconds

  @override
  void initState() {
    super.initState();
    // Schedule data loading after the current frame to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadComments();
      }
    });
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Start automatic refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (mounted) {
        _refreshComments();
      }
    });
  }

  Future<void> _loadComments() async {
    final commentsProvider = context.read<CommentsProvider>();
    await commentsProvider.fetchComments(widget.reelId);
  }

  Future<void> _refreshComments({bool showMessage = false}) async {
    final commentsProvider = context.read<CommentsProvider>();
    final previousCount = commentsProvider.currentCommentCount;
    
    await commentsProvider.fetchComments(widget.reelId, refresh: true);
    
    if (!mounted) return;
    
    // Show notification if there are changes and message is requested
    if (showMessage) {
      final newCount = commentsProvider.currentCommentCount;
      final diff = newCount - previousCount;
      
      if (diff != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              diff > 0 
                  ? '📝 $diff new comment${diff > 1 ? "s" : ""}' 
                  : '📝 ${diff.abs()} comment${diff.abs() > 1 ? "s" : ""} removed',
            ),
            backgroundColor: diff > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: const Text('Comments'),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Manual Refresh Button
          Consumer<CommentsProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: provider.isLoading ? Colors.white54 : Colors.white,
                ),
                tooltip: 'Refresh comments',
                onPressed: provider.isLoading 
                    ? null 
                    : () => _refreshComments(showMessage: true),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Reel Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reel',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.reelDescription,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Consumer<CommentsProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${provider.currentCommentCount} comments '
                          '(${provider.newCommentCount} new)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.autorenew,
                              size: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Auto-refresh every ${_autoRefreshInterval.inSeconds}s',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: Consumer<CommentsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const LoadingIndicator(message: 'Loading comments...');
                }

                if (provider.error != null) {
                  return ErrorDisplay(
                    message: provider.error!,
                    onRetry: _loadComments,
                  );
                }

                if (provider.currentComments.isEmpty) {
                  return EmptyState(
                    icon: Icons.comment_outlined,
                    title: 'No Comments',
                    message: 'No comments found for this reel.',
                    actionLabel: 'Refresh',
                    onAction: _refreshComments,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _refreshComments(showMessage: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.currentComments.length,
                    itemBuilder: (context, index) {
                      final comment = provider.currentComments[index];
                      return CommentCard(
                        comment: comment,
                        onReply: (message) => _replyToComment(comment.id, message),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replyToComment(String commentId, String message) async {
    final commentsProvider = context.read<CommentsProvider>();
    final success = await commentsProvider.replyToComment(commentId, message);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(commentsProvider.error ?? 'Failed to post reply'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

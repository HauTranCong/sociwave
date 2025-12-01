import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/api_client_provider.dart';
import '../providers/comments_provider.dart';
import '../providers/config_provider.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_display.dart';
import '../widgets/comment_card.dart';

/// Screen for viewing and replying to comments
class CommentsScreen extends StatefulWidget {
  final String reelId;
  final String reelDescription;
  final String? pageId;

  const CommentsScreen({
    super.key,
    required this.reelId,
    required this.reelDescription,
    this.pageId,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  String? _pageId;

  @override
  void initState() {
    super.initState();
    _pageId = widget.pageId;
    if (_pageId != null && _pageId!.isNotEmpty) {
      // Scope API calls to the page that owns this reel
      context.read<ApiClientProvider>().setPageId(_pageId);
    }
    // Schedule data loading after the current frame to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadComments();
      }
    });
  }

  Future<void> _loadComments() async {
    final commentsProvider = context.read<CommentsProvider>();
    if (_pageId != null && _pageId!.isNotEmpty) {
      commentsProvider.setPageScope(_pageId!);
    }
    await commentsProvider.fetchComments(widget.reelId);
  }

  Future<void> _refreshComments({bool showMessage = false}) async {
    final commentsProvider = context.read<CommentsProvider>();
    final previousCount = commentsProvider.currentCommentCount;

    if (_pageId != null && _pageId!.isNotEmpty) {
      commentsProvider.setPageScope(_pageId!);
    }
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

  Future<void> _openReelLink() async {
    final url = Uri.parse('https://www.facebook.com/reel/${widget.reelId}');
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the reel link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageLabel = _pageId != null
        ? context.read<ConfigProvider>().pageLabel(_pageId!)
        : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refreshComments(showMessage: true),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Back',
                            onPressed: () => context.pop(),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comments',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (pageLabel != null)
                                Text(
                                  pageLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Consumer<CommentsProvider>(
                            builder: (context, provider, _) {
                              return TextButton.icon(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _refreshComments(showMessage: true),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _openReelLink,
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Open Reel'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.reelDescription,
                                style: theme.textTheme.titleMedium,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Consumer<CommentsProvider>(
                                builder: (context, provider, _) {
                                  return Text(
                                    '${provider.currentCommentCount} comments',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Consumer<CommentsProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: LoadingIndicator(message: 'Loading comments...'),
                      ),
                    );
                  }

                  if (provider.error != null) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ErrorDisplay(
                          message: provider.error!,
                          onRetry: _loadComments,
                        ),
                      ),
                    );
                  }

                  if (provider.currentComments.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: EmptyState(
                          icon: Icons.comment_outlined,
                          title: 'No Comments',
                          message: 'No comments found for this reel.',
                          actionLabel: 'Refresh',
                          onAction: _refreshComments,
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: provider.currentComments.length,
                      itemBuilder: (context, index) {
                        final comment = provider.currentComments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CommentCard(
                            comment: comment,
                            onReply: (message) =>
                                _replyToComment(comment.id, message),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
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

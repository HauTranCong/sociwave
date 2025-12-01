import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/utils/validators.dart';
import '../domain/models/config.dart';
import '../providers/config_provider.dart';
import '../providers/reels_provider.dart';
import '../providers/comments_provider.dart';
import '../router/app_router.dart';
import '../widgets/loading_overlay.dart';

/// Settings screen for API configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late ConfigProvider _configProvider;
  late TextEditingController _tokenController;
  late TextEditingController _versionController;
  late TextEditingController _reelsLimitController;
  late TextEditingController _commentsLimitController;
  late TextEditingController _repliesLimitController;
  bool _useMockData = false;
  bool _isLoading = false;
  Config? _lastSyncedConfig;
  bool _isListeningToConfig = false;
  bool _isEditingPage = false;
  String? _editingPageId;

  @override
  void initState() {
    super.initState();
    _configProvider = context.read<ConfigProvider>();
    final config = _configProvider.config;
    _tokenController = TextEditingController();
    _versionController = TextEditingController();
    _reelsLimitController = TextEditingController();
    _commentsLimitController = TextEditingController();
    _repliesLimitController = TextEditingController();
    _applyConfigToForm(config, silent: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _configProvider.addListener(_handleConfigChanged);
      _isListeningToConfig = true;

      // Safe to access GoRouterState here (after initState completes)
      final routerState = GoRouterState.of(context);
      final routeExtra = routerState.extra;
      if (routeExtra is Map && routeExtra['pageId'] is String) {
        _editingPageId = (routeExtra['pageId'] as String);
      }

      // If editing a specific page, load its config into the form
      if (_editingPageId != null) {
        final cfg = await _configProvider.getConfigForPage(_editingPageId!);
        if (cfg != null) {
          _applyConfigToForm(cfg);
        } else {
          _applyConfigToForm(_buildConfigForPage(pageId: _editingPageId!));
        }
      }
    });
  }

  @override
  void dispose() {
    if (_isListeningToConfig) {
      _configProvider.removeListener(_handleConfigChanged);
    }
    _tokenController.dispose();
    _versionController.dispose();
    _reelsLimitController.dispose();
    _commentsLimitController.dispose();
    _repliesLimitController.dispose();
    super.dispose();
  }

  void _handleConfigChanged() {
    final config = _configProvider.config;
    // Avoid overwriting an in-flight edit for a different page
    if (_isEditingPage &&
        _editingPageId != null &&
        _editingPageId != config.pageId) {
      return;
    }
    if (_lastSyncedConfig == config) return;
    _applyConfigToForm(config);
  }

  Widget _buildPageManager(BuildContext context, ConfigProvider provider) {
    final pages = provider.managedPages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No pages added yet. Use the "Add Facebook Page" card to create your first scoped configuration.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _buildAddPageCard(context),
        ...pages.map(
          (pageId) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildPageCard(context, pageId, provider),
          ),
        ),
      ],
    );
  }

  Widget _buildPageCard(
    BuildContext context,
    String pageId,
    ConfigProvider provider,
  ) {
    final theme = Theme.of(context);
    final pageLabel = provider.pageLabel(pageId);
    final isConnected = provider.isPageConnected(pageId);
    final borderColor = Colors.grey.withOpacity(
      theme.brightness == Brightness.dark ? 0.45 : 0.25,
    );
    final backgroundColor = theme.cardColor;
    final isConfigured = provider.isPageConfigured(pageId);
    final iconColor = isConnected ? Colors.green : Colors.grey.withOpacity(0.8);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isLoading ? 0.6 : 1,
      child: SizedBox(
        width: double.infinity,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: borderColor, width: 1),
          ),
          color: backgroundColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _isLoading
                ? null
                : () {
                    _handleSelectPage(pageId);
                  },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, color: iconColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pageLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _handleRemovePage(pageId),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent.shade200,
                          size: 20,
                        ),
                        label: Text(
                          'Remove',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.redAccent.shade200,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent.shade200,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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

  Widget _buildAddPageCard(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isLoading ? 0.4 : 1,
      child: SizedBox(
        width: double.infinity,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _isLoading ? null : _handleAddPage,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add Facebook Page',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a new page configuration',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSelectPage(String pageId) async {
    if (_configProvider.selectedPageId == pageId) {
      setState(() => _isEditingPage = true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final config = await _configProvider.getConfigForPage(pageId);
      if (config != null) {
        _applyConfigToForm(config);
        _editingPageId = pageId;
      } else {
        _applyConfigToForm(_buildConfigForPage(pageId: pageId));
        _editingPageId = pageId;
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEditingPage = true;
      });
    }
  }

  Future<void> _handleAddPage() async {
    final newPageData = await _promptForPageConfig();
    final newPageId = newPageData?['pageId'] ?? '';
    final token = newPageData?['token'] ?? '';
    if (newPageId.isEmpty) return;
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide an access token for the new page.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final configForPage = _buildConfigForPage(
      pageId: newPageId,
      tokenOverride: token,
    );
    setState(() => _isLoading = true);
    try {
      // Immediately show the scoped config in the form, then persist to backend
      _applyConfigToForm(configForPage);
      final success = await _configProvider.saveConfigForPage(configForPage);
      if (!success) {
        final error = _configProvider.error ?? 'Failed to save configuration';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Page added and configuration saved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEditingPage = true;
      });
    }
  }

  Future<void> _handleRemovePage(String pageId) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove page?'),
            content: Text(
              'This will remove "$pageId" from the app and delete its configuration from the server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      await _configProvider.removePage(pageId);
      final error = _configProvider.error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Page removed and backend data deleted.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEditingPage = _configProvider.selectedPageId != null;
      });
    }
  }

  void _applyConfigToForm(Config config, {bool silent = false}) {
    void sync() {
      _tokenController.text = config.token;
      _versionController.text = config.version;
      _reelsLimitController.text = config.reelsLimit.toString();
      _commentsLimitController.text = config.commentsLimit.toString();
      _repliesLimitController.text = config.repliesLimit.toString();
      _useMockData = config.useMockData;
      _lastSyncedConfig = config;
    }

    if (silent || !mounted) {
      sync();
    } else {
      setState(sync);
    }
  }

  void _exitConfigView() {
    if (!_isEditingPage) return;
    setState(() {
      _isEditingPage = false;
      _editingPageId = null;
    });
  }

  Widget _buildConfigCard(BuildContext context, ConfigProvider provider) {
    final theme = Theme.of(context);
    final pageId = _editingPageId ?? provider.selectedPageId ?? 'Unknown Page';
    final pageLabel = provider.pageLabel(pageId);
    final isConnected = provider.isPageConnected(pageId);
    final statusColor = isConnected ? Colors.green : Colors.orangeAccent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _isLoading ? null : _exitConfigView,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to page list',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editing Configuration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        pageLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(isConnected ? 'Connected' : 'Not Connected'),
                  backgroundColor: statusColor.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ..._buildConfigFormFields(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfigFormFields(BuildContext context) {
    return [
      TextFormField(
        controller: _tokenController,
        decoration: const InputDecoration(
          labelText: 'Access Token',
          hintText: 'Enter your Facebook Graph API access token',
          prefixIcon: Icon(Icons.key),
          helperText: 'Get this from Facebook Developers Portal',
        ),
        validator: (value) => Validators.validateToken(value ?? ''),
        obscureText: true,
        maxLines: 1,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _versionController,
        decoration: const InputDecoration(
          labelText: 'API Version',
          hintText: 'e.g., v24.0',
          prefixIcon: Icon(Icons.code),
          helperText: 'Facebook Graph API version',
        ),
        validator: (value) => Validators.validateApiVersion(value ?? ''),
      ),
      const SizedBox(height: 24),
      Text(
        'API Request Limits',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        'Configure how many items to fetch per API request. Set "Replies Limit" to control how many nested replies are fetched for each comment.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _reelsLimitController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Reels Limit',
          hintText: 'Max reels per request (1-10000)',
          prefixIcon: Icon(Icons.video_library),
          helperText: 'Number of reels to fetch (default: 25)',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Reels limit is required';
          }
          final limit = int.tryParse(value);
          if (limit == null) {
            return 'Please enter a valid number';
          }
          if (limit < 1 || limit > 10000) {
            return 'Limit must be between 1 and 10000';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _commentsLimitController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Comments Limit',
          hintText: 'Max comments per request (1-50000)',
          prefixIcon: Icon(Icons.comment),
          helperText: 'Number of comments to fetch (default: 100)',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Comments limit is required';
          }
          final limit = int.tryParse(value);
          if (limit == null) {
            return 'Please enter a valid number';
          }
          if (limit < 1 || limit > 50000) {
            return 'Limit must be between 1 and 50000';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _repliesLimitController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Replies Limit',
          hintText: 'Max replies per comment (1-100)',
          prefixIcon: Icon(Icons.reply),
          helperText: 'Number of replies to fetch per comment (default: 100)',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Replies limit is required';
          }
          final limit = int.tryParse(value);
          if (limit == null) {
            return 'Please enter a valid number';
          }
          if (limit < 1 || limit > 100) {
            return 'Limit must be between 1 and 100';
          }
          return null;
        },
      ),
      const SizedBox(height: 24),
      Card(
        child: SwitchListTile(
          title: const Text('Use Mock Data'),
          subtitle: const Text('For development and testing without real API'),
          value: _useMockData,
          onChanged: (value) {
            setState(() => _useMockData = value);
          },
          secondary: Icon(
            _useMockData ? Icons.science : Icons.cloud,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveConfiguration,
        icon: const Icon(Icons.save),
        label: const Text('Save Configuration'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      const SizedBox(height: 16),
      Card(
        color: Colors.blue[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'How to get Access Token',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1. Go to developers.facebook.com\n'
                '2. Create or select an app\n'
                '3. Add Facebook Login product\n'
                '4. Generate User Access Token\n'
                '5. Grant pages_read_engagement and pages_manage_posts permissions',
                style: TextStyle(color: Colors.grey[800]),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Future<Map<String, String>?> _promptForPageConfig() async {
    final idController = TextEditingController();
    final tokenController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Facebook Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Page ID',
                hintText: 'Enter Facebook Page ID or "me"',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Access Token',
                hintText: 'Paste the page access token',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final pageId = idController.text.trim();
              final token = tokenController.text.trim();
              if (pageId.isEmpty) return;
              Navigator.of(context).pop({'pageId': pageId, 'token': token});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    idController.dispose();
    tokenController.dispose();
    return result;
  }

  Config _buildConfigForPage({required String pageId, String? tokenOverride}) {
    final versionText = _versionController.text.trim();
    return Config(
      token: (tokenOverride ?? _tokenController.text).trim(),
      version: versionText.isEmpty ? 'v24.0' : versionText,
      pageId: pageId,
      useMockData: _useMockData,
      reelsLimit: int.tryParse(_reelsLimitController.text.trim()) ?? 25,
      commentsLimit: int.tryParse(_commentsLimitController.text.trim()) ?? 100,
      repliesLimit: int.tryParse(_repliesLimitController.text.trim()) ?? 100,
    );
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final configProvider = _configProvider;
    final pageId = _editingPageId ?? configProvider.selectedPageId;
    if (pageId == null || pageId.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a Facebook Page before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final config = _buildConfigForPage(pageId: pageId);

    final success = await configProvider.saveConfigForPage(config);

    if (!mounted) return;

    if (success) {
      // Reinitialize API-dependent providers
      context.read<ReelsProvider>().initialize(config);
      context.read<CommentsProvider>().initialize(config);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to dashboard
      context.go(AppRouter.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(configProvider.error ?? 'Failed to save configuration'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = context.watch<ConfigProvider>();
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _isEditingPage
                    ? _buildConfigCard(context, configProvider)
                    : _buildPageManager(context, configProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

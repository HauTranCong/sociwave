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
  late TextEditingController _tokenController;
  late TextEditingController _versionController;
  late TextEditingController _pageIdController;
  late TextEditingController _reelsLimitController;
  late TextEditingController _commentsLimitController;
  late TextEditingController _repliesLimitController;
  bool _useMockData = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<ConfigProvider>().config;
    _tokenController = TextEditingController(text: config.token);
    _versionController = TextEditingController(text: config.version);
    _pageIdController = TextEditingController(text: config.pageId);
    _reelsLimitController = TextEditingController(
      text: config.reelsLimit.toString(),
    );
    _commentsLimitController = TextEditingController(
      text: config.commentsLimit.toString(),
    );
    _repliesLimitController = TextEditingController(
      text: config.repliesLimit.toString(),
    );
    _useMockData = config.useMockData;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _versionController.dispose();
    _pageIdController.dispose();
    _reelsLimitController.dispose();
    _commentsLimitController.dispose();
    _repliesLimitController.dispose();
    super.dispose();
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final config = Config(
      token: _tokenController.text.trim(),
      version: _versionController.text.trim(),
      pageId: _pageIdController.text.trim(),
      useMockData: _useMockData,
      reelsLimit: int.tryParse(_reelsLimitController.text.trim()) ?? 25,
      commentsLimit: int.tryParse(_commentsLimitController.text.trim()) ?? 100,
      repliesLimit: int.tryParse(_repliesLimitController.text.trim()) ?? 100,
    );

    final configProvider = context.read<ConfigProvider>();
    final success = await configProvider.saveConfig(config);

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
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Align(
            alignment: Alignment.centerLeft,
            child: const Text('Settings'),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Facebook API Configuration',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure your Facebook API credentials to start monitoring comments',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Access Token Field
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

                // API Version Field
                TextFormField(
                  controller: _versionController,
                  decoration: const InputDecoration(
                    labelText: 'API Version',
                    hintText: 'e.g., v24.0',
                    prefixIcon: Icon(Icons.code),
                    helperText: 'Facebook Graph API version',
                  ),
                  validator: (value) =>
                      Validators.validateApiVersion(value ?? ''),
                ),
                const SizedBox(height: 16),

                // Page ID Field
                TextFormField(
                  controller: _pageIdController,
                  decoration: const InputDecoration(
                    labelText: 'Page ID',
                    hintText: 'Enter Facebook Page ID or "me"',
                    prefixIcon: Icon(Icons.badge),
                    helperText: 'Use "me" for current user or specific page ID',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Page ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // API Limits Section
                Text(
                  'API Request Limits',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure how many items to fetch per API request. Set "Replies Limit" to control how many nested replies are fetched for each comment.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                // Reels Limit Field
                TextFormField(
                  controller: _reelsLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reels Limit',
                    hintText: 'Max reels per request (1-100)',
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
                    if (limit < 1 || limit > 100) {
                      return 'Limit must be between 1 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Comments Limit Field
                TextFormField(
                  controller: _commentsLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Comments Limit',
                    hintText: 'Max comments per request (1-100)',
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
                    if (limit < 1 || limit > 100) {
                      return 'Limit must be between 1 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Replies Limit Field
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

                // Mock Data Switch
                Card(
                  child: SwitchListTile(
                    title: const Text('Use Mock Data'),
                    subtitle: const Text(
                      'For development and testing without real API',
                    ),
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
                const SizedBox(height: 32),

                // Save Button
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

                // Help Text
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

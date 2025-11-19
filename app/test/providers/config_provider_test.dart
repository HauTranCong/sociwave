import 'package:flutter_test/flutter_test.dart';
import 'package:sociwave/data/services/storage_service.dart';
import 'package:sociwave/domain/models/config.dart';
import 'package:sociwave/providers/config_provider.dart';

void main() {
  late StorageService storage;
  late ConfigProvider provider;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    storage = await StorageService.init();
    provider = ConfigProvider(storage);
  });

  group('ConfigProvider Tests', () {
    test('initial config should be invalid', () {
      expect(provider.config.isValid, false);
      expect(provider.isConfigured, false);
    });

    test('saving valid config should work', () async {
      final config = Config(
        token: 'test_token',
        version: 'v1.0',
        pageId: '123456',
        useMockData: true,
      );

      final result = await provider.saveConfig(config);
      
      expect(result, true);
      expect(provider.config, config);
      expect(provider.isConfigured, true);
    });

    test('updating config should merge values', () async {
      // First save initial config
      await provider.saveConfig(Config(
        token: 'initial_token',
        version: 'v1.0',
        pageId: '123',
        useMockData: false,
      ));

      // Then update just the token
      await provider.updateConfig(token: 'new_token');
      
      expect(provider.config.token, 'new_token');
      expect(provider.config.version, 'v1.0'); // Should remain unchanged
      expect(provider.config.pageId, '123'); // Should remain unchanged
    });

    test('clearing config should reset to initial', () async {
      // Save config first
      await provider.saveConfig(Config(
        token: 'test_token',
        version: 'v1.0',
        pageId: '123',
        useMockData: true,
      ));
      
      expect(provider.isConfigured, true);

      // Clear config
      await provider.clearConfig();
      
      expect(provider.isConfigured, false);
      expect(provider.config.token, '');
    });

    test('validateConfig should check validity', () {
      // Invalid config
      expect(provider.validateConfig(), false);
      expect(provider.error, isNotNull);

      // Valid config
      provider.saveConfig(Config(
        token: 'test_token',
        version: 'v1.0',
        pageId: '123',
        useMockData: true,
      ));
      
      expect(provider.validateConfig(), true);
      expect(provider.error, isNull);
    });
  });
}

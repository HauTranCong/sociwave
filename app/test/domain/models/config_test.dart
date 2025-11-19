import 'package:flutter_test/flutter_test.dart';
import 'package:sociwave/domain/models/config.dart';

void main() {
  group('Config Model', () {
    test('should create config with all fields', () {
      const config = Config(
        token: 'test_token',
        version: 'v24.0',
        pageId: '123',
        useMockData: true,
      );

      expect(config.token, 'test_token');
      expect(config.version, 'v24.0');
      expect(config.pageId, '123');
      expect(config.useMockData, true);
    });

    test('should create initial config', () {
      final config = Config.initial();

      expect(config.token, '');
      expect(config.version, 'v24.0');
      expect(config.pageId, 'me');
      expect(config.useMockData, false);
    });

    test('should convert to and from JSON', () {
      const config = Config(
        token: 'test_token',
        version: 'v18.0',
        pageId: 'me',
        useMockData: false,
      );

      final json = config.toJson();
      final decoded = Config.fromJson(json);

      expect(decoded.token, config.token);
      expect(decoded.version, config.version);
      expect(decoded.pageId, config.pageId);
      expect(decoded.useMockData, config.useMockData);
    });

    test('should copy with modified fields', () {
      const original = Config(
        token: 'old_token',
        version: 'v18.0',
        pageId: 'me',
        useMockData: false,
      );

      final modified = original.copyWith(
        token: 'new_token',
        useMockData: true,
      );

      expect(modified.token, 'new_token');
      expect(modified.version, 'v18.0'); // unchanged
      expect(modified.pageId, 'me'); // unchanged
      expect(modified.useMockData, true);
    });

    test('should validate correctly', () {
      const validConfig = Config(
        token: 'test_token',
        version: 'v24.0',
        pageId: '123',
      );
      expect(validConfig.isValid, true);

      const invalidConfig = Config(
        token: '',
        version: 'v24.0',
        pageId: '123',
      );
      expect(invalidConfig.isValid, false);
    });

    test('should check production mode', () {
      const prodConfig = Config(
        token: 'test_token',
        version: 'v24.0',
        pageId: '123',
        useMockData: false,
      );
      expect(prodConfig.isProduction, true);

      const mockConfig = Config(
        token: 'test_token',
        version: 'v24.0',
        pageId: '123',
        useMockData: true,
      );
      expect(mockConfig.isProduction, false);
    });

    test('should support equality comparison', () {
      const config1 = Config(
        token: 'test',
        version: 'v24.0',
        pageId: 'me',
      );
      const config2 = Config(
        token: 'test',
        version: 'v24.0',
        pageId: 'me',
      );
      const config3 = Config(
        token: 'different',
        version: 'v24.0',
        pageId: 'me',
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });
  });
}

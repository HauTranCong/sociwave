import 'package:flutter_test/flutter_test.dart';
import 'package:sociwave/data/services/storage_service.dart';
import 'package:sociwave/domain/models/rule.dart';
import 'package:sociwave/providers/rules_provider.dart';

void main() {
  late StorageService storage;
  late RulesProvider provider;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    storage = await StorageService.init();
    provider = RulesProvider(storage);
  });

  group('RulesProvider Tests', () {
    test('initial state should be empty', () {
      expect(provider.rules, isEmpty);
      expect(provider.ruleCount, 0);
      expect(provider.enabledRuleCount, 0);
    });

    test('saving rule should work', () async {
      final rule = Rule(
        objectId: 'reel_123',
        matchWords: ['hello', 'hi'],
        replyMessage: 'Thanks for your comment!',
        enabled: true,
      );

      final result = await provider.saveRule(rule);
      
      expect(result, true);
      expect(provider.ruleCount, 1);
      expect(provider.enabledRuleCount, 1);
      expect(provider.getRule('reel_123'), rule);
    });

    test('updating rule should replace existing', () async {
      final rule1 = Rule(
        objectId: 'reel_123',
        matchWords: ['hello'],
        replyMessage: 'Message 1',
        enabled: true,
      );

      await provider.saveRule(rule1);
      expect(provider.ruleCount, 1);

      final rule2 = rule1.copyWith(replyMessage: 'Message 2');
      await provider.saveRule(rule2);
      
      expect(provider.ruleCount, 1); // Still 1, not 2
      expect(provider.getRule('reel_123')!.replyMessage, 'Message 2');
    });

    test('toggling rule should change enabled state', () async {
      final rule = Rule(
        objectId: 'reel_123',
        matchWords: ['test'],
        replyMessage: 'Reply',
        enabled: true,
      );

      await provider.saveRule(rule);
      expect(provider.isRuleEnabled('reel_123'), true);

      await provider.toggleRule('reel_123');
      expect(provider.isRuleEnabled('reel_123'), false);

      await provider.toggleRule('reel_123');
      expect(provider.isRuleEnabled('reel_123'), true);
    });

    test('deleting rule should remove it', () async {
      final rule = Rule(
        objectId: 'reel_123',
        matchWords: ['test'],
        replyMessage: 'Reply',
        enabled: true,
      );

      await provider.saveRule(rule);
      expect(provider.hasRule('reel_123'), true);

      await provider.deleteRule('reel_123');
      expect(provider.hasRule('reel_123'), false);
      expect(provider.ruleCount, 0);
    });

    test('getEnabledRules should return only enabled rules', () async {
      await provider.saveRule(Rule(
        objectId: 'reel_1',
        matchWords: ['test'],
        replyMessage: 'Reply',
        enabled: true,
      ));

      await provider.saveRule(Rule(
        objectId: 'reel_2',
        matchWords: ['test'],
        replyMessage: 'Reply',
        enabled: false,
      ));

      await provider.saveRule(Rule(
        objectId: 'reel_3',
        matchWords: ['test'],
        replyMessage: 'Reply',
        enabled: true,
      ));

      final enabledRules = provider.getEnabledRules();
      expect(enabledRules.length, 2);
      expect(enabledRules.containsKey('reel_1'), true);
      expect(enabledRules.containsKey('reel_3'), true);
    });

    test('validateRule should check validity', () {
      final validRule = Rule(
        objectId: 'reel_123',
        matchWords: ['test'],
        replyMessage: 'Reply',
        enabled: true,
      );

      expect(provider.validateRule(validRule), true);

      final invalidRule = Rule(
        objectId: 'reel_123',
        matchWords: ['test'],
        replyMessage: '', // Empty reply message
        enabled: true,
      );

      expect(provider.validateRule(invalidRule), false);
      expect(provider.error, isNotNull);
    });
  });
}

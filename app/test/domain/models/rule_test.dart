import 'package:flutter_test/flutter_test.dart';
import 'package:sociwave/domain/models/rule.dart';

void main() {
  group('Rule Model', () {
    test('should create rule with all fields', () {
      const rule = Rule(
        objectId: '123',
        matchWords: ['hello', 'hi'],
        replyMessage: 'Thanks for your comment!',
        inboxMessage: 'Private message',
        enabled: true,
      );

      expect(rule.objectId, '123');
      expect(rule.matchWords, ['hello', 'hi']);
      expect(rule.replyMessage, 'Thanks for your comment!');
      expect(rule.inboxMessage, 'Private message');
      expect(rule.enabled, true);
    });

    test('should create empty rule', () {
      final rule = Rule.empty('456');

      expect(rule.objectId, '456');
      expect(rule.matchWords, isEmpty);
      expect(rule.replyMessage, '');
      expect(rule.inboxMessage, null);
      expect(rule.enabled, false);
    });

    test('should convert to and from JSON', () {
      const rule = Rule(
        objectId: '789',
        matchWords: ['test'],
        replyMessage: 'Reply',
        enabled: true,
      );

      final json = rule.toJson();
      final decoded = Rule.fromJson('789', json);

      expect(decoded.objectId, rule.objectId);
      expect(decoded.matchWords, rule.matchWords);
      expect(decoded.replyMessage, rule.replyMessage);
      expect(decoded.enabled, rule.enabled);
    });

    test('should match comments correctly - empty match words', () {
      const rule = Rule(
        objectId: '1',
        matchWords: [],
        replyMessage: 'Reply',
      );

      expect(rule.matches('any comment'), true);
      expect(rule.matches('another comment'), true);
    });

    test('should match comments correctly - single dot', () {
      const rule = Rule(
        objectId: '1',
        matchWords: ['.'],
        replyMessage: 'Reply',
      );

      expect(rule.matches('any comment'), true);
      expect(rule.matches(''), true);
    });

    test('should match comments correctly - specific keywords', () {
      const rule = Rule(
        objectId: '1',
        matchWords: ['hello', 'hi', 'greetings'],
        replyMessage: 'Reply',
      );

      expect(rule.matches('Hello world!'), true);
      expect(rule.matches('Hi there'), true);
      expect(rule.matches('Greetings friend'), true);
      expect(rule.matches('goodbye'), false);
    });

    test('should match case-insensitively', () {
      const rule = Rule(
        objectId: '1',
        matchWords: ['TEST'],
        replyMessage: 'Reply',
      );

      expect(rule.matches('test'), true);
      expect(rule.matches('Test'), true);
      expect(rule.matches('TEST'), true);
      expect(rule.matches('This is a test'), true);
    });

    test('should validate correctly', () {
      const validRule = Rule(
        objectId: '1',
        matchWords: ['test'],
        replyMessage: 'Reply',
      );
      expect(validRule.isValid, true);

      const invalidRule = Rule(
        objectId: '1',
        matchWords: ['test'],
        replyMessage: '',
      );
      expect(invalidRule.isValid, false);
    });

    test('should provide keyword count', () {
      const rule = Rule(
        objectId: '1',
        matchWords: ['a', 'b', 'c'],
        replyMessage: 'Reply',
      );
      expect(rule.keywordCount, 3);
    });

    test('should provide keywords summary', () {
      const rule1 = Rule(
        objectId: '1',
        matchWords: [],
        replyMessage: 'Reply',
      );
      expect(rule1.keywordsSummary, 'All comments');

      const rule2 = Rule(
        objectId: '1',
        matchWords: ['.'],
        replyMessage: 'Reply',
      );
      expect(rule2.keywordsSummary, 'All comments');

      const rule3 = Rule(
        objectId: '1',
        matchWords: ['a', 'b'],
        replyMessage: 'Reply',
      );
      expect(rule3.keywordsSummary, 'a, b');

      const rule4 = Rule(
        objectId: '1',
        matchWords: ['a', 'b', 'c', 'd', 'e'],
        replyMessage: 'Reply',
      );
      expect(rule4.keywordsSummary, contains('a, b, c'));
      expect(rule4.keywordsSummary, contains('+2 more'));
    });

    test('should copy with modified fields', () {
      const original = Rule(
        objectId: '1',
        matchWords: ['old'],
        replyMessage: 'Old reply',
        enabled: false,
      );

      final modified = original.copyWith(
        matchWords: ['new'],
        enabled: true,
      );

      expect(modified.matchWords, ['new']);
      expect(modified.enabled, true);
      expect(modified.replyMessage, 'Old reply'); // unchanged
    });
  });
}

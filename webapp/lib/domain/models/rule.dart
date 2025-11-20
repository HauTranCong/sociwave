import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rule.g.dart';

/// Rule for automated comment replies
/// 
/// Corresponds to Python's rules.json structure
@JsonSerializable(createFactory: false)
class Rule extends Equatable {
  /// The object ID (reel/post) this rule applies to
  /// Not stored in JSON - used as the key in the rules map
  final String objectId;
  
  /// List of keywords to match in comments (case-insensitive)
  /// Empty list or single "." means match all comments
  @JsonKey(name: 'match_words', defaultValue: [])
  final List<String> matchWords;
  
  /// Reply message to post when keywords match
  @JsonKey(name: 'reply_message', defaultValue: '')
  final String replyMessage;
  
  /// Optional private message to send (not yet implemented)
  @JsonKey(name: 'inbox_message')
  final String? inboxMessage;
  
  /// Whether this rule is active
  @JsonKey(defaultValue: false)
  final bool enabled;

  const Rule({
    required this.objectId,
    required this.matchWords,
    required this.replyMessage,
    this.inboxMessage,
    this.enabled = false,
  });

  /// Create an empty/default rule for a specific object
  factory Rule.empty(String objectId) {
    return Rule(
      objectId: objectId,
      matchWords: [],
      replyMessage: '',
      inboxMessage: null,
      enabled: false,
    );
  }

  /// Create Rule from JSON with objectId
  factory Rule.fromJson(String objectId, Map<String, dynamic> json) {
    return Rule(
      objectId: objectId,
      matchWords: (json['match_words'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      replyMessage: json['reply_message'] as String? ?? '',
      inboxMessage: json['inbox_message'] as String?,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  /// Convert Rule to JSON (without objectId)
  Map<String, dynamic> toJson() => _$RuleToJson(this);

  /// Create a copy with modified fields
  Rule copyWith({
    String? objectId,
    List<String>? matchWords,
    String? replyMessage,
    String? inboxMessage,
    bool? enabled,
  }) {
    return Rule(
      objectId: objectId ?? this.objectId,
      matchWords: matchWords ?? this.matchWords,
      replyMessage: replyMessage ?? this.replyMessage,
      inboxMessage: inboxMessage ?? this.inboxMessage,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Check if a comment text matches this rule's keywords
  /// 
  /// Logic from Python:
  /// - If matchWords is null or empty, matches all
  /// - If matchWords contains single ".", matches all
  /// - Otherwise, checks if any keyword appears in comment (case-insensitive)
  bool matches(String commentText) {
    final lowerComment = commentText.toLowerCase();
    
    // Empty or null match_words means match all
    if (matchWords.isEmpty) {
      return true;
    }
    
    // Single "." means match all
    if (matchWords.length == 1 && matchWords[0] == '.') {
      return true;
    }
    
    // Check if any keyword matches
    return matchWords.any((keyword) {
      return lowerComment.contains(keyword.toLowerCase());
    });
  }

  /// Check if rule is properly configured
  bool get isValid {
    return replyMessage.isNotEmpty;
  }

  /// Get number of keywords
  int get keywordCount => matchWords.length;

  /// Get summary of keywords (for display)
  String get keywordsSummary {
    if (matchWords.isEmpty) {
      return 'All comments';
    }
    if (matchWords.length == 1 && matchWords[0] == '.') {
      return 'All comments';
    }
    if (matchWords.length <= 3) {
      return matchWords.join(', ');
    }
    return '${matchWords.take(3).join(', ')}... (+${matchWords.length - 3} more)';
  }

  @override
  List<Object?> get props => [
    objectId,
    matchWords,
    replyMessage,
    inboxMessage,
    enabled,
  ];

  @override
  String toString() {
    return 'Rule(objectId: $objectId, enabled: $enabled, keywords: ${matchWords.length})';
  }
}

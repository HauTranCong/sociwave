import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'comment.g.dart';

/// Comment author information
@JsonSerializable()
class CommentAuthor extends Equatable {
  /// Author's Facebook user ID
  final String id;
  
  /// Author's display name
  final String name;

  const CommentAuthor({
    required this.id,
    required this.name,
  });

  /// Create CommentAuthor from JSON
  factory CommentAuthor.fromJson(Map<String, dynamic> json) =>
      _$CommentAuthorFromJson(json);

  /// Convert CommentAuthor to JSON
  Map<String, dynamic> toJson() => _$CommentAuthorToJson(this);

  /// Get initials for avatar display
  String get initials {
    final parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  List<Object?> get props => [id, name];

  @override
  String toString() => 'CommentAuthor(id: $id, name: $name)';
}

/// Comment on a Facebook post/reel
/// 
/// Corresponds to Facebook Graph API comments endpoint response
@JsonSerializable()
class Comment extends Equatable {
  /// Unique comment ID from Facebook
  final String id;
  
  /// Comment text/message
  final String message;
  
  /// Comment author information (nullable for deleted users/comments)
  final CommentAuthor? from;
  
  /// When the comment was created
  @JsonKey(name: 'created_time')
  final DateTime createdTime;
  
  /// When the comment was last updated (optional)
  @JsonKey(name: 'updated_time')
  final DateTime? updatedTime;
  
  /// Nested replies to this comment
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<Comment>? replies;
  
  /// Whether we have already replied to this comment (computed, not from API)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool hasReplied;

  const Comment({
    required this.id,
    required this.message,
    this.from,
    required this.createdTime,
    this.updatedTime,
    this.replies,
    this.hasReplied = false,
  });

  /// Create Comment from JSON with null safety for deleted users
  factory Comment.fromJson(Map<String, dynamic> json) {
    // Handle deleted user/comment case where 'from' is null
    CommentAuthor? author;
    if (json['from'] != null) {
      author = CommentAuthor.fromJson(json['from'] as Map<String, dynamic>);
    }
    
    // Handle nested replies
    List<Comment>? replies;
    if (json['comments'] != null) {
      final commentsData = json['comments'] as Map<String, dynamic>;
      if (commentsData['data'] != null) {
        final repliesData = commentsData['data'] as List<dynamic>;
        replies = repliesData
            .map((replyJson) => Comment.fromJson(replyJson as Map<String, dynamic>))
            .where((reply) => reply.from != null) // Filter out deleted user replies
            .toList();
      }
    }
    
    return Comment(
      id: json['id'] as String,
      message: json['message'] as String? ?? '[Comment deleted]',
      from: author,
      createdTime: DateTime.parse(json['created_time'] as String),
      updatedTime: json['updated_time'] == null
          ? null
          : DateTime.parse(json['updated_time'] as String),
      replies: replies,
    );
  }

  /// Convert Comment to JSON
  Map<String, dynamic> toJson() => _$CommentToJson(this);

  /// Create a copy with modified fields
  Comment copyWith({
    String? id,
    String? message,
    CommentAuthor? from,
    DateTime? createdTime,
    DateTime? updatedTime,
    List<Comment>? replies,
    bool? hasReplied,
  }) {
    return Comment(
      id: id ?? this.id,
      message: message ?? this.message,
      from: from ?? this.from,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
      replies: replies ?? this.replies,
      hasReplied: hasReplied ?? this.hasReplied,
    );
  }

  /// Get effective timestamp (updated or created)
  DateTime get effectiveTime => updatedTime ?? createdTime;

  /// Check if comment was edited
  bool get isEdited => updatedTime != null && updatedTime != createdTime;

  /// Get truncated message for list display
  String get shortMessage {
    if (message.isEmpty) return '(No message)';
    return message.length > 100
        ? '${message.substring(0, 100)}...'
        : message;
  }

  /// Get message word count
  int get wordCount => message.trim().split(RegExp(r'\s+')).length;

  /// Get Facebook permalink URL for this comment
  String get permalinkUrl {
    // Facebook comment URL format: https://www.facebook.com/{comment_id}
    return 'https://www.facebook.com/$id';
  }

  @override
  List<Object?> get props => [
    id,
    message,
    from,
    createdTime,
    updatedTime,
    replies,
    hasReplied,
  ];

  @override
  String toString() {
    return 'Comment(id: $id, from: ${from?.name ?? "[Deleted User]"}, hasReplied: $hasReplied)';
  }
  
  /// Get author name with fallback for deleted users
  String get authorName => from?.name ?? '[Deleted User]';
  
  /// Get author ID with fallback for deleted users
  String get authorId => from?.id ?? 'unknown';
  
  /// Check if the page has already replied to this comment
  /// Returns true if any reply in the nested replies is from the specified pageId
  bool hasPageReplied(String pageId) {
    if (replies == null || replies!.isEmpty) return false;
    return replies!.any((reply) => reply.from?.id == pageId);
  }
}

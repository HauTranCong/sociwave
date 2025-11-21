import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'config.g.dart';

/// Configuration model for API settings
///
/// Corresponds to Python's config.json structure
@JsonSerializable()
class Config extends Equatable {
  /// Facebook Graph API access token
  final String token;

  /// API version (e.g., "v24.0", "v18.0")
  final String version;

  /// Facebook Page ID or "me" for current user
  final String pageId;

  /// Whether to use mock data for development/testing
  final bool useMockData;

  /// Maximum number of reels to fetch per request (1-100)
  @JsonKey(name: 'reels_limit', defaultValue: 25)
  final int reelsLimit;

  /// Maximum number of comments to fetch per request (1-100)
  @JsonKey(name: 'comments_limit', defaultValue: 100)
  final int commentsLimit;

  /// Maximum number of replies to fetch per comment (1-100)
  @JsonKey(name: 'replies_limit', defaultValue: 100)
  final int repliesLimit;

  const Config({
    required this.token,
    required this.version,
    required this.pageId,
    this.useMockData = false,
    this.reelsLimit = 25,
    this.commentsLimit = 100,
    this.repliesLimit = 100,
  });

  /// Default configuration with empty values
  factory Config.initial() {
    return const Config(
      token: '',
      version: 'v24.0',
      pageId: 'me',
      useMockData: false,
      reelsLimit: 25,
      commentsLimit: 100,
      repliesLimit: 100,
    );
  }

  /// Create Config from JSON
  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

  /// Convert Config to JSON
  Map<String, dynamic> toJson() => _$ConfigToJson(this);

  /// Create a copy with modified fields
  Config copyWith({
    String? token,
    String? version,
    String? pageId,
    bool? useMockData,
    int? reelsLimit,
    int? commentsLimit,
    int? repliesLimit,
  }) {
    return Config(
      token: token ?? this.token,
      version: version ?? this.version,
      pageId: pageId ?? this.pageId,
      useMockData: useMockData ?? this.useMockData,
      reelsLimit: reelsLimit ?? this.reelsLimit,
      commentsLimit: commentsLimit ?? this.commentsLimit,
      repliesLimit: repliesLimit ?? this.repliesLimit,
    );
  }

  /// Check if configuration is valid
  bool get isValid {
    return token.isNotEmpty && version.isNotEmpty && pageId.isNotEmpty;
  }

  /// Check if using production data (not mock)
  bool get isProduction => !useMockData && token.isNotEmpty;

  @override
  List<Object?> get props => [
    token,
    version,
    pageId,
    useMockData,
    reelsLimit,
    commentsLimit,
    repliesLimit,
  ];

  @override
  String toString() {
    return 'Config(version: $version, pageId: $pageId, useMockData: $useMockData, reelsLimit: $reelsLimit, commentsLimit: $commentsLimit, repliesLimit: $repliesLimit)';
  }
}

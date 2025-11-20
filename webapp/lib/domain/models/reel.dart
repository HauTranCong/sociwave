import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reel.g.dart';

/// Model for Facebook Video Reel
/// 
/// Corresponds to Facebook Graph API video_reels endpoint response
@JsonSerializable()
class Reel extends Equatable {
  /// Unique reel ID from Facebook
  final String id;
  
  /// Reel description/caption (optional)
  final String? description;
  
  /// Last updated timestamp
  @JsonKey(name: 'updated_time')
  final DateTime updatedTime;
  
  /// Whether this reel has a rule configured (computed, not from API)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool hasRule;
  
  /// Whether the rule for this reel is enabled (computed, not from API)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool ruleEnabled;

  const Reel({
    required this.id,
    this.description,
    required this.updatedTime,
    this.hasRule = false,
    this.ruleEnabled = false,
  });

  /// Create Reel from JSON
  factory Reel.fromJson(Map<String, dynamic> json) => _$ReelFromJson(json);

  /// Convert Reel to JSON
  Map<String, dynamic> toJson() => _$ReelToJson(this);

  /// Create a copy with modified fields
  Reel copyWith({
    String? id,
    String? description,
    DateTime? updatedTime,
    bool? hasRule,
    bool? ruleEnabled,
  }) {
    return Reel(
      id: id ?? this.id,
      description: description ?? this.description,
      updatedTime: updatedTime ?? this.updatedTime,
      hasRule: hasRule ?? this.hasRule,
      ruleEnabled: ruleEnabled ?? this.ruleEnabled,
    );
  }

  /// Get display text for the reel (description or ID)
  String get displayText => description?.trim().isNotEmpty == true
      ? description!
      : 'Reel ID: $id';
  
  /// Get display title (alias for displayText)
  String get displayTitle => displayText;

  /// Get truncated description for list display
  String get shortDescription {
    if (description == null || description!.isEmpty) {
      return 'No description';
    }
    return description!.length > 100
        ? '${description!.substring(0, 100)}...'
        : description!;
  }
  
  /// Get relative time string (e.g., "2 hours ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(updatedTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  @override
  List<Object?> get props => [id, description, updatedTime, hasRule, ruleEnabled];

  @override
  String toString() {
    return 'Reel(id: $id, hasRule: $hasRule, ruleEnabled: $ruleEnabled)';
  }
}

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'monitor_status.g.dart';

/// Status of the background monitoring service
@JsonSerializable()
class MonitorStatus extends Equatable {
  /// Whether the monitoring service is currently running
  final bool isRunning;
  
  /// Timestamp of the last monitoring check
  @JsonKey(name: 'last_check')
  final DateTime? lastCheck;
  
  /// Total number of monitoring checks performed
  @JsonKey(name: 'total_checks', defaultValue: 0)
  final int totalChecks;
  
  /// Total number of automated replies sent
  @JsonKey(name: 'total_replies', defaultValue: 0)
  final int totalReplies;
  
  /// Last error message (if any)
  @JsonKey(name: 'last_error')
  final String? lastError;
  
  /// Timestamp of the last error
  @JsonKey(name: 'last_error_time')
  final DateTime? lastErrorTime;

  const MonitorStatus({
    this.isRunning = false,
    this.lastCheck,
    this.totalChecks = 0,
    this.totalReplies = 0,
    this.lastError,
    this.lastErrorTime,
  });

  /// Initial/default status
  factory MonitorStatus.initial() {
    return const MonitorStatus(
      isRunning: false,
      lastCheck: null,
      totalChecks: 0,
      totalReplies: 0,
      lastError: null,
      lastErrorTime: null,
    );
  }

  /// Create MonitorStatus from JSON
  factory MonitorStatus.fromJson(Map<String, dynamic> json) =>
      _$MonitorStatusFromJson(json);

  /// Convert MonitorStatus to JSON
  Map<String, dynamic> toJson() => _$MonitorStatusToJson(this);

  /// Create a copy with modified fields
  MonitorStatus copyWith({
    bool? isRunning,
    DateTime? lastCheck,
    int? totalChecks,
    int? totalReplies,
    String? lastError,
    DateTime? lastErrorTime,
  }) {
    return MonitorStatus(
      isRunning: isRunning ?? this.isRunning,
      lastCheck: lastCheck ?? this.lastCheck,
      totalChecks: totalChecks ?? this.totalChecks,
      totalReplies: totalReplies ?? this.totalReplies,
      lastError: lastError ?? this.lastError,
      lastErrorTime: lastErrorTime ?? this.lastErrorTime,
    );
  }

  /// Increment check count
  MonitorStatus incrementChecks() {
    return copyWith(
      totalChecks: totalChecks + 1,
      lastCheck: DateTime.now(),
    );
  }

  /// Increment reply count
  MonitorStatus incrementReplies() {
    return copyWith(totalReplies: totalReplies + 1);
  }

  /// Set error
  MonitorStatus withError(String error) {
    return copyWith(
      lastError: error,
      lastErrorTime: DateTime.now(),
    );
  }

  /// Clear error
  MonitorStatus clearError() {
    return copyWith(
      lastError: null,
      lastErrorTime: null,
    );
  }

  /// Get time since last check
  Duration? get timeSinceLastCheck {
    if (lastCheck == null) return null;
    return DateTime.now().difference(lastCheck!);
  }

  /// Check if there's a recent error (within last 5 minutes)
  bool get hasRecentError {
    if (lastError == null || lastErrorTime == null) return false;
    final timeSinceError = DateTime.now().difference(lastErrorTime!);
    return timeSinceError.inMinutes < 5;
  }

  /// Get average replies per check (if any checks performed)
  double get averageRepliesPerCheck {
    if (totalChecks == 0) return 0.0;
    return totalReplies / totalChecks;
  }

  /// Get status summary text
  String get statusText {
    if (!isRunning) return 'Stopped';
    if (hasRecentError) return 'Error';
    if (lastCheck == null) return 'Starting...';
    return 'Running';
  }

  @override
  List<Object?> get props => [
    isRunning,
    lastCheck,
    totalChecks,
    totalReplies,
    lastError,
    lastErrorTime,
  ];

  @override
  String toString() {
    return 'MonitorStatus(isRunning: $isRunning, checks: $totalChecks, replies: $totalReplies)';
  }
}

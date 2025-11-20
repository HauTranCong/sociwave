// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonitorStatus _$MonitorStatusFromJson(Map<String, dynamic> json) =>
    MonitorStatus(
      isRunning: json['isRunning'] as bool? ?? false,
      lastCheck: json['last_check'] == null
          ? null
          : DateTime.parse(json['last_check'] as String),
      totalChecks: (json['total_checks'] as num?)?.toInt() ?? 0,
      totalReplies: (json['total_replies'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
      lastErrorTime: json['last_error_time'] == null
          ? null
          : DateTime.parse(json['last_error_time'] as String),
    );

Map<String, dynamic> _$MonitorStatusToJson(MonitorStatus instance) =>
    <String, dynamic>{
      'isRunning': instance.isRunning,
      'last_check': instance.lastCheck?.toIso8601String(),
      'total_checks': instance.totalChecks,
      'total_replies': instance.totalReplies,
      'last_error': instance.lastError,
      'last_error_time': instance.lastErrorTime?.toIso8601String(),
    };

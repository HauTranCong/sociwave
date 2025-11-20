// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Reel _$ReelFromJson(Map<String, dynamic> json) => Reel(
  id: json['id'] as String,
  description: json['description'] as String?,
  updatedTime: DateTime.parse(json['updated_time'] as String),
);

Map<String, dynamic> _$ReelToJson(Reel instance) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'updated_time': instance.updatedTime.toIso8601String(),
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Config _$ConfigFromJson(Map<String, dynamic> json) => Config(
  token: json['token'] as String,
  version: json['version'] as String,
  pageId: json['pageId'] as String,
  useMockData: json['useMockData'] as bool? ?? false,
);

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
  'token': instance.token,
  'version': instance.version,
  'pageId': instance.pageId,
  'useMockData': instance.useMockData,
};

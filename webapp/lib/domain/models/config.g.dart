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
  reelsLimit: (json['reels_limit'] as num?)?.toInt() ?? 25,
  commentsLimit: (json['comments_limit'] as num?)?.toInt() ?? 100,
  repliesLimit: (json['replies_limit'] as num?)?.toInt() ?? 100,
);

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
  'token': instance.token,
  'version': instance.version,
  'pageId': instance.pageId,
  'useMockData': instance.useMockData,
  'reels_limit': instance.reelsLimit,
  'comments_limit': instance.commentsLimit,
  'replies_limit': instance.repliesLimit,
};

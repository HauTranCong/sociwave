// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommentAuthor _$CommentAuthorFromJson(Map<String, dynamic> json) =>
    CommentAuthor(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$CommentAuthorToJson(CommentAuthor instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

Comment _$CommentFromJson(Map<String, dynamic> json) => Comment(
  id: json['id'] as String,
  message: json['message'] as String,
  from: json['from'] == null
      ? null
      : CommentAuthor.fromJson(json['from'] as Map<String, dynamic>),
  createdTime: DateTime.parse(json['created_time'] as String),
  updatedTime: json['updated_time'] == null
      ? null
      : DateTime.parse(json['updated_time'] as String),
);

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
  'id': instance.id,
  'message': instance.message,
  'from': instance.from,
  'created_time': instance.createdTime.toIso8601String(),
  'updated_time': instance.updatedTime?.toIso8601String(),
};

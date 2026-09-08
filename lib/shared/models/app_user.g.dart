// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  id: json['id'] as String,
  pseudo: json['pseudo'] as String,
  colorAccent: json['color_accent'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  isAdmin: json['is_admin'] as bool? ?? false,
  profileCompleted: json['profile_completed'] as bool? ?? false,
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'pseudo': instance.pseudo,
  'color_accent': instance.colorAccent,
  'created_at': instance.createdAt.toIso8601String(),
  'is_admin': instance.isAdmin,
  'profile_completed': instance.profileCompleted,
};

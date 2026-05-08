// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'species.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Species _$SpeciesFromJson(Map<String, dynamic> json) => _Species(
  id: json['id'] as String,
  commonName: json['common_name'] as String,
  scientificName: json['scientific_name'] as String,
  categoryId: json['category_id'] as String,
  description: json['description'] as String?,
  photoUrl: json['photo_url'] as String?,
  createdByUserId: json['created_by_user_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$SpeciesToJson(_Species instance) => <String, dynamic>{
  'id': instance.id,
  'common_name': instance.commonName,
  'scientific_name': instance.scientificName,
  'category_id': instance.categoryId,
  'description': instance.description,
  'photo_url': instance.photoUrl,
  'created_by_user_id': instance.createdByUserId,
  'created_at': instance.createdAt.toIso8601String(),
};

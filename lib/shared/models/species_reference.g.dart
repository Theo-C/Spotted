// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'species_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SpeciesReference _$SpeciesReferenceFromJson(Map<String, dynamic> json) =>
    _SpeciesReference(
      scientificName: json['scientific_name'] as String,
      commonName: json['common_name'] as String,
      categoryKey: json['category_key'] as String,
      rarityHint: json['rarity_hint'] as String?,
      description: json['description'] as String,
      tips: json['tips'] as String,
      photoUrl: json['photo_url'] as String?,
    );

Map<String, dynamic> _$SpeciesReferenceToJson(_SpeciesReference instance) =>
    <String, dynamic>{
      'scientific_name': instance.scientificName,
      'common_name': instance.commonName,
      'category_key': instance.categoryKey,
      'rarity_hint': instance.rarityHint,
      'description': instance.description,
      'tips': instance.tips,
      'photo_url': instance.photoUrl,
    };

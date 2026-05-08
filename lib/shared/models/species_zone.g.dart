// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'species_zone.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SpeciesZone _$SpeciesZoneFromJson(Map<String, dynamic> json) => _SpeciesZone(
  speciesId: json['species_id'] as String,
  zoneId: json['zone_id'] as String,
  rarity: $enumDecode(_$RarityEnumMap, json['rarity']),
);

Map<String, dynamic> _$SpeciesZoneToJson(_SpeciesZone instance) =>
    <String, dynamic>{
      'species_id': instance.speciesId,
      'zone_id': instance.zoneId,
      'rarity': _$RarityEnumMap[instance.rarity]!,
    };

const _$RarityEnumMap = {
  Rarity.common: 'common',
  Rarity.rare: 'rare',
  Rarity.epic: 'epic',
  Rarity.legendary: 'legendary',
};

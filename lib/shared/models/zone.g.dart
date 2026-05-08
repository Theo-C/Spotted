// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Zone _$ZoneFromJson(Map<String, dynamic> json) => _Zone(
  id: json['id'] as String,
  countryId: json['country_id'] as String,
  name: json['name'] as String,
  shortCode: json['short_code'] as String?,
  type: $enumDecode(_$ZoneTypeEnumMap, json['type']),
  geojsonUrl: json['geojson_url'] as String?,
);

Map<String, dynamic> _$ZoneToJson(_Zone instance) => <String, dynamic>{
  'id': instance.id,
  'country_id': instance.countryId,
  'name': instance.name,
  'short_code': instance.shortCode,
  'type': _$ZoneTypeEnumMap[instance.type]!,
  'geojson_url': instance.geojsonUrl,
};

const _$ZoneTypeEnumMap = {
  ZoneType.country: 'country',
  ZoneType.region: 'region',
  ZoneType.department: 'department',
  ZoneType.park: 'park',
  ZoneType.custom: 'custom',
};

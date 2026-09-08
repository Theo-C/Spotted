// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'observation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Observation _$ObservationFromJson(Map<String, dynamic> json) => _Observation(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  speciesId: json['species_id'] as String,
  zoneId: json['zone_id'] as String?,
  observedAt: DateTime.parse(json['observed_at'] as String),
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  photoUrl: json['photo_url'] as String?,
  photoExifData: json['photo_exif_data'] as Map<String, dynamic>?,
  isFirstForUser: json['is_first_for_user'] as bool,
  pointsEarned: (json['points_earned'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  wasDailySpecies: json['was_daily_species'] as bool? ?? false,
);

Map<String, dynamic> _$ObservationToJson(_Observation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'species_id': instance.speciesId,
      'zone_id': instance.zoneId,
      'observed_at': instance.observedAt.toIso8601String(),
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'photo_url': instance.photoUrl,
      'photo_exif_data': instance.photoExifData,
      'is_first_for_user': instance.isFirstForUser,
      'points_earned': instance.pointsEarned,
      'created_at': instance.createdAt.toIso8601String(),
      'was_daily_species': instance.wasDailySpecies,
    };

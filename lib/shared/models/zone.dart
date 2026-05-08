import 'package:freezed_annotation/freezed_annotation.dart';

import 'zone_type.dart';

part 'zone.freezed.dart';
part 'zone.g.dart';

@freezed
abstract class Zone with _$Zone {
  const factory Zone({
    required String id,
    required String countryId,
    required String name,
    String? shortCode,
    required ZoneType type,
    String? geojsonUrl,
  }) = _Zone;

  factory Zone.fromJson(Map<String, dynamic> json) => _$ZoneFromJson(json);
}

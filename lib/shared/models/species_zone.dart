import 'package:freezed_annotation/freezed_annotation.dart';

import 'rarity.dart';

part 'species_zone.freezed.dart';
part 'species_zone.g.dart';

@freezed
abstract class SpeciesZone with _$SpeciesZone {
  const factory SpeciesZone({
    required String speciesId,
    required String zoneId,
    required Rarity rarity,
  }) = _SpeciesZone;

  factory SpeciesZone.fromJson(Map<String, dynamic> json) =>
      _$SpeciesZoneFromJson(json);
}

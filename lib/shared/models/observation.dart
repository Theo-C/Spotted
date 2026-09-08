import 'package:freezed_annotation/freezed_annotation.dart';

part 'observation.freezed.dart';
part 'observation.g.dart';

@freezed
abstract class Observation with _$Observation {
  const factory Observation({
    required String id,
    required String userId,
    required String speciesId,
    String? zoneId,
    required DateTime observedAt,
    required double latitude,
    required double longitude,
    String? photoUrl,
    Map<String, dynamic>? photoExifData,
    required bool isFirstForUser,
    required int pointsEarned,
    required DateTime createdAt,
    @Default(false) bool wasDailySpecies,
  }) = _Observation;

  factory Observation.fromJson(Map<String, dynamic> json) =>
      _$ObservationFromJson(json);
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'species.freezed.dart';
part 'species.g.dart';

@freezed
abstract class Species with _$Species {
  const factory Species({
    required String id,
    required String commonName,
    required String scientificName,
    required String categoryId,
    String? description,
    /// Conseil terrain "Pour la débusquer" — affiché sur la fiche détail
    /// tant que l'espèce n'a pas été observée. Court (1-2 phrases).
    String? tips,
    String? photoUrl,
    String? createdByUserId,
    required DateTime createdAt,
  }) = _Species;

  factory Species.fromJson(Map<String, dynamic> json) =>
      _$SpeciesFromJson(json);
}

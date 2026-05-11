import 'package:freezed_annotation/freezed_annotation.dart';

part 'species_reference.freezed.dart';
part 'species_reference.g.dart';

/// Entrée de la banque de référence d'espèces (`species_reference` table).
/// Sert à pré-remplir le formulaire d'ajout d'espèce dans `_AddSpeciesDialog`
/// quand le user accepte un candidat IA dont le scientific_name correspond
/// à une espèce déjà documentée dans la référence.
///
/// Distinct de [Species] qui contient les espèces que les users ont
/// effectivement curées dans leur catalogue (avec id Supabase, etc.).
@freezed
abstract class SpeciesReference with _$SpeciesReference {
  const factory SpeciesReference({
    required String scientificName,
    required String commonName,

    /// Clé de catégorie (birds/mammals/reptiles/bats) — matche
    /// `categories.icon` côté DB.
    required String categoryKey,

    /// Rareté suggérée (common/rare/epic/legendary). Indicative —
    /// l'user peut l'ajuster selon son territoire.
    String? rarityHint,

    required String description,
    required String tips,

    /// URL d'une photo d'illustration (CC, depuis iNaturalist).
    String? photoUrl,
  }) = _SpeciesReference;

  factory SpeciesReference.fromJson(Map<String, dynamic> json) =>
      _$SpeciesReferenceFromJson(json);
}

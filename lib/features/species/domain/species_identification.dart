/// Résultat d'une identification IA d'espèce depuis une photo.
/// Renvoyé par [SpeciesIdentificationService.identifyFromFile].
class SpeciesIdentification {
  const SpeciesIdentification({
    required this.detected,
    required this.commonName,
    required this.scientificName,
    required this.categoryKey,
    required this.rarityKey,
    required this.confidence,
    required this.rationale,
  });

  /// false si l'IA n'a pas pu identifier (paysage, photo floue, etc.).
  final bool detected;

  /// Nom commun français (ex: "Buse variable").
  final String commonName;

  /// Nom binominal latin (ex: "Buteo buteo").
  /// C'est ce champ qui sert au matching avec [Species.scientificName] en BDD.
  final String scientificName;

  /// Identifiant de catégorie : "birds" | "mammals" | "reptiles" | "bats".
  /// Doit correspondre à [Category.icon] côté BDD.
  final String categoryKey;

  /// Rareté proposée : "common" | "rare" | "epic" | "legendary".
  /// Doit correspondre à [Rarity.name] côté BDD.
  final String rarityKey;

  /// Confiance de l'IA dans son identification (0.0–1.0).
  /// On affiche un avertissement explicite si < 0.6.
  final double confidence;

  /// Phrase courte qui justifie l'identification (transparence pour l'user).
  final String rationale;

  factory SpeciesIdentification.fromJson(Map<String, dynamic> json) {
    return SpeciesIdentification(
      detected: json['detected'] as bool? ?? false,
      commonName: (json['common_name'] as String? ?? '').trim(),
      scientificName: (json['scientific_name'] as String? ?? '').trim(),
      categoryKey: (json['category_key'] as String? ?? '').trim(),
      rarityKey: (json['rarity_key'] as String? ?? '').trim(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rationale: (json['rationale'] as String? ?? '').trim(),
    );
  }
}

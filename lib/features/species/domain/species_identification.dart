/// Une espèce candidate avec son score, dans un résultat top-N.
class SpeciesCandidate {
  const SpeciesCandidate({
    required this.commonName,
    required this.scientificName,
    required this.categoryKey,
    required this.rarityKey,
    required this.confidence,
  });

  /// Nom commun français (ex: "Grand Corbeau").
  final String commonName;

  /// Nom binominal latin (ex: "Corvus corax"). Sert au matching BDD.
  final String scientificName;

  /// "birds" | "mammals" | "reptiles" | "bats".
  final String categoryKey;

  /// "common" | "rare" | "epic" | "legendary".
  final String rarityKey;

  /// Score (0.0–1.0) — confiance relative parmi les candidats.
  final double confidence;

  factory SpeciesCandidate.fromJson(Map<String, dynamic> json) {
    return SpeciesCandidate(
      commonName: (json['common_name'] as String? ?? '').trim(),
      scientificName: (json['scientific_name'] as String? ?? '').trim(),
      categoryKey: (json['category_key'] as String? ?? '').trim(),
      rarityKey: (json['rarity_key'] as String? ?? '').trim(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Résultat d'une identification IA — plusieurs candidats classés par confiance.
/// Le mode top-N atténue le "tout ou rien" du mode 1-seule-suggestion :
/// même si le modèle se trompe en #1, le user retrouve souvent la bonne en #2/#3.
class SpeciesIdentification {
  const SpeciesIdentification({
    required this.detected,
    required this.candidates,
    required this.rationale,
  });

  /// false si la photo ne montre pas un animal sauvage identifiable.
  final bool detected;

  /// Liste de 1 à 3 candidats, classés par confiance décroissante.
  /// Vide si [detected] == false.
  final List<SpeciesCandidate> candidates;

  /// Phrase courte qui justifie l'identification (transparence).
  final String rationale;

  /// Premier candidat (le plus probable selon l'IA), ou null si rien.
  SpeciesCandidate? get top => candidates.isEmpty ? null : candidates.first;

  factory SpeciesIdentification.fromJson(Map<String, dynamic> json) {
    final raw = json['candidates'] as List? ?? const [];
    final candidates = raw
        .cast<Map<String, dynamic>>()
        .map(SpeciesCandidate.fromJson)
        .where((c) => c.scientificName.isNotEmpty)
        .toList();
    return SpeciesIdentification(
      detected: json['detected'] as bool? ?? false,
      candidates: candidates,
      rationale: (json['rationale'] as String? ?? '').trim(),
    );
  }
}

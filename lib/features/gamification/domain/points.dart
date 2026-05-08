import '../../../shared/models/rarity.dart';

/// Source unique de vérité pour le calcul des points (cf. CLAUDE.md §règles métier).
const Map<Rarity, int> pointsByRarity = {
  Rarity.common: 10,
  Rarity.rare: 30,
  Rarity.epic: 100,
  Rarity.legendary: 300,
};

/// Points pour une 1ʳᵉ observation, sans photo.
int firstObservationPoints(Rarity r) => pointsByRarity[r]!;

/// Re-observation = 20% du base, arrondi sup → 2/6/20/60.
int reobservationPoints(Rarity r) =>
    (pointsByRarity[r]! * 0.2).ceil();

/// Bonus photo : +50% sur les deux types d'obs (arrondi normal).
int withPhotoBonus(int basePoints) =>
    (basePoints * 1.5).round();

/// Combo helper — points crédités pour une obs donnée.
int observationPoints({
  required Rarity rarity,
  required bool isFirst,
  required bool hasPhoto,
}) {
  final base = isFirst
      ? firstObservationPoints(rarity)
      : reobservationPoints(rarity);
  return hasPhoto ? withPhotoBonus(base) : base;
}

/// Bonus rétroactif si on ajoute une photo à une 1ʳᵉ obs déjà validée
/// sans photo. Différence entre points avec photo et points actuels.
int retroactivePhotoBonus(Rarity r) =>
    withPhotoBonus(firstObservationPoints(r)) - firstObservationPoints(r);

/// "Étoiles" de rareté pour l'UI (1 = commun, 4 = légendaire).
int rarityStars(Rarity r) => switch (r) {
      Rarity.common => 1,
      Rarity.rare => 2,
      Rarity.epic => 3,
      Rarity.legendary => 4,
    };

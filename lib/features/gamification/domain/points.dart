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
///
/// Ordre d'application des multiplicateurs (empilement du "plus intrinsèque"
/// au "plus contextuel") :
///   1. Base rareté (1ʳᵉ ou re-obs)
///   2. Bonus photo (+50%) — si photo jointe
///   3. Bonus espèce du jour (x2) — si obs de l'espèce tirée pour aujourd'hui
///   4. Multiplicateur série ([streakMultiplier]) — amplifie tout le reste
///
/// [isDailySpecies] : true si l'espèce observée est celle tirée pour l'user
/// pour aujourd'hui (cf. daily_species). Applique un x2 sur les points.
int observationPoints({
  required Rarity rarity,
  required bool isFirst,
  required bool hasPhoto,
  bool isDailySpecies = false,
  double streakMultiplier = 1.0,
}) {
  final base = isFirst
      ? firstObservationPoints(rarity)
      : reobservationPoints(rarity);
  final withPhoto = hasPhoto ? withPhotoBonus(base) : base;
  final withDaily = isDailySpecies ? withPhoto * 2 : withPhoto;
  if (streakMultiplier == 1.0) return withDaily;
  return (withDaily * streakMultiplier).round();
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

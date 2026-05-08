import 'dart:math' as math;

/// État de progression d'un niveau (calcul pur, pas de couplage Riverpod).
class LevelInfo {
  const LevelInfo({
    required this.value,
    required this.currentPoints,
    required this.currentThreshold,
    required this.nextThreshold,
  });

  /// Numéro du niveau (1, 2, 3...).
  final int value;

  /// Points cumulés actuels.
  final int currentPoints;

  /// Seuil minimal pour être à ce niveau.
  final int currentThreshold;

  /// Seuil minimal pour passer au niveau suivant.
  final int nextThreshold;

  int get pointsToNext => (nextThreshold - currentPoints).clamp(0, 1 << 30);

  /// Fraction de progression (0.0–1.0) vers le niveau suivant.
  double get progressFraction {
    final span = nextThreshold - currentThreshold;
    if (span <= 0) return 1;
    return ((currentPoints - currentThreshold) / span).clamp(0.0, 1.0);
  }
}

/// Niveau atteint pour un total de points donné.
/// Formule : `level = 1 + floor(sqrt(points / 100))`
/// → 0 pts = niv 1, 100 = niv 2, 400 = niv 3, 1600 = niv 5, 4900 = niv 8.
int levelFromPoints(int points) {
  if (points <= 0) return 1;
  return 1 + math.sqrt(points / 100).floor();
}

/// Seuil de points cumulés pour atteindre le niveau [level].
/// Formule : `(level - 1)² × 100`.
int thresholdForLevel(int level) {
  if (level <= 1) return 0;
  final n = level - 1;
  return n * n * 100;
}

LevelInfo computeLevel(int points) {
  final level = levelFromPoints(points);
  return LevelInfo(
    value: level,
    currentPoints: points,
    currentThreshold: thresholdForLevel(level),
    nextThreshold: thresholdForLevel(level + 1),
  );
}

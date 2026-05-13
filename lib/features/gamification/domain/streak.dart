import '../../../shared/models/observation.dart';

/// État de la série (streak) d'un utilisateur.
class Streak {
  const Streak({
    required this.current,
    required this.longest,
    required this.isActiveToday,
    required this.isInGrace,
    this.isPaused = false,
    this.lastObservationDate,
  });

  /// Nombre de jours consécutifs en cours.
  /// - 0 si aucune obs OU série vraiment perdue (gap > 2 jours).
  /// - Sinon = longueur de la chaîne, y compris si elle est `isPaused`
  ///   (chaîne préservée pour l'affichage en attendant l'obs du jour).
  final int current;

  /// Record historique de l'user (>= current).
  final int longest;

  /// True si l'user a observé aujourd'hui.
  final bool isActiveToday;

  /// True si l'user a observé hier mais pas aujourd'hui : 1 jour de grâce
  /// avant de perdre sa série (sa série compte encore comme active pour
  /// le multiplicateur). UI : flamme orange.
  final bool isInGrace;

  /// True si la dernière obs est avant-hier (gap de 2 jours, dernière chance
  /// de rattraper avant rupture définitive). La chaîne est préservée dans
  /// [current] pour rester visible, mais le multiplicateur XP est désactivé
  /// (1 jour de grâce uniquement, pas 2). UI : flamme bleue.
  final bool isPaused;

  /// Date de la dernière observation. Null si l'user n'a jamais observé.
  final DateTime? lastObservationDate;

  /// Multiplicateur XP appliqué aux nouvelles obs selon le palier de série
  /// courant. 1.0 = pas de bonus, 1.5 = +50%.
  /// Pendant une pause, on retombe à 1.0 — la règle est "1 jour de grâce",
  /// pas 2. L'user doit obs aujourd'hui pour réactiver le multiplicateur.
  double get xpMultiplier {
    if (isPaused) return 1.0;
    if (current >= 100) return 1.5;
    if (current >= 30) return 1.25;
    if (current >= 7) return 1.1;
    return 1.0;
  }

  /// Palier suivant (en jours) — pour afficher "encore N jours avant +X%".
  int? get nextThreshold {
    if (current < 7) return 7;
    if (current < 30) return 30;
    if (current < 100) return 100;
    if (current < 365) return 365;
    return null;
  }

  /// Nombre de jours restants pour atteindre le prochain palier.
  int? get daysToNextThreshold {
    final next = nextThreshold;
    return next == null ? null : next - current;
  }

  static const empty = Streak(
    current: 0,
    longest: 0,
    isActiveToday: false,
    isInGrace: false,
  );
}

/// Calcule la série à partir des dates d'observation d'un user.
///
/// Règle : 1 jour de grâce, avec un état "pause" intermédiaire.
///   - J (aujourd'hui) : obs → active, current = chaîne
///   - J−1 : seule la veille a observé → grâce, current = chaîne, mult conservé
///   - J−2 : avant-hier mais pas hier ni aujourd'hui → PAUSE, current = chaîne
///           (préservée pour rester visible) mais multiplicateur reset à 1.0.
///           Une obs aujourd'hui rattrape la série (le gap de 2 est toléré
///           dans le comptage interne).
///   - > J−2 : série vraiment rompue, current = 0.
///
/// Algorithme :
///   1. Trier obs par date desc, garder uniquement la date (jour) sans heure
///   2. Dédupliquer (plusieurs obs le même jour = 1 jour dans la chaîne)
///   3. Si gap entre aujourd'hui et la dernière obs > 2 → série brisée (0)
///   4. Sinon compter les jours en chaîne avec tolérance gap ≤ 2 (1 jour
///      sauté autorisé entre deux obs voisines)
Streak computeStreak(List<Observation> observations, {DateTime? now}) {
  if (observations.isEmpty) return Streak.empty;

  final today = _truncateToDay(now ?? DateTime.now());

  // Set des jours uniques où il y a eu au moins une obs, triés desc
  final obsDays = observations
      .map((o) => _truncateToDay(o.observedAt))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  final lastObsDate = obsDays.first;
  final daysSinceLastObs = today.difference(lastObsDate).inDays;

  // Gap > 2 jours = série vraiment perdue (irrattrapable par une obs
  // aujourd'hui, vu que la règle de chaîne tolère gap ≤ 2).
  if (daysSinceLastObs > 2) {
    return Streak(
      current: 0,
      longest: _computeLongestEver(obsDays),
      isActiveToday: false,
      isInGrace: false,
      isPaused: false,
      lastObservationDate: lastObsDate,
    );
  }

  // Compte les jours en chaîne. Tolérance gap ≤ 2 (1 jour sauté autorisé).
  var current = 1;
  for (var i = 1; i < obsDays.length; i++) {
    final gap = obsDays[i - 1].difference(obsDays[i]).inDays;
    if (gap <= 2) {
      current++;
    } else {
      break;
    }
  }

  return Streak(
    current: current,
    longest: _computeLongestEver(obsDays).clamp(current, 1 << 30),
    isActiveToday: daysSinceLastObs == 0,
    isInGrace: daysSinceLastObs == 1,
    isPaused: daysSinceLastObs == 2,
    lastObservationDate: lastObsDate,
  );
}

/// Plus longue série historique (parcourt toutes les obs pour trouver le max).
int _computeLongestEver(List<DateTime> obsDaysSortedDesc) {
  if (obsDaysSortedDesc.isEmpty) return 0;
  var longest = 1;
  var run = 1;
  for (var i = 1; i < obsDaysSortedDesc.length; i++) {
    final gap = obsDaysSortedDesc[i - 1].difference(obsDaysSortedDesc[i]).inDays;
    if (gap <= 2) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }
  return longest;
}

DateTime _truncateToDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

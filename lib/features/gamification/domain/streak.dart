import '../../../shared/models/observation.dart';

/// État de la série (streak) d'un utilisateur.
class Streak {
  const Streak({
    required this.current,
    required this.longest,
    required this.isActiveToday,
    required this.isInGrace,
    this.lastObservationDate,
  });

  /// Nombre de jours consécutifs en cours (peut être 0).
  final int current;

  /// Record historique de l'user (>= current).
  final int longest;

  /// True si l'user a observé aujourd'hui (la série est "validée" pour le jour).
  final bool isActiveToday;

  /// True si l'user a 1 jour de grâce avant de perdre sa série (a observé hier
  /// mais pas aujourd'hui). UI : flamme orange/clignotante pour signaler l'urgence.
  final bool isInGrace;

  /// Date de la dernière observation. Null si l'user n'a jamais observé.
  final DateTime? lastObservationDate;

  /// Multiplicateur XP appliqué aux nouvelles obs selon le palier de série courant.
  /// 1.0 = pas de bonus, 1.5 = +50%.
  double get xpMultiplier {
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
/// Règle : 1 jour de grâce.
///   - Aujourd'hui (J) : observé → série +1, "active"
///   - J n'observe pas, J-1 a observé → série maintenue, état "in grace"
///   - J et J-1 : pas d'obs → série reset à 0
///
/// Algorithme :
///   1. Trier obs par date desc, garder uniquement la date (jour) sans l'heure
///   2. Dédupliquer (un user peut faire plusieurs obs le même jour)
///   3. Parcourir depuis la plus récente, compter les jours consécutifs
///      avec tolérance de 1 jour entre obs (= règle de grâce)
///   4. Stopper dès qu'un gap > 1 jour apparaît
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

  // Distance en jours entre aujourd'hui et la dernière obs
  final daysSinceLastObs = today.difference(lastObsDate).inDays;

  // Si > 1 jour de gap entre aujourd'hui et la dernière obs : série rompue
  if (daysSinceLastObs > 1) {
    return Streak(
      current: 0,
      longest: _computeLongestEver(obsDays),
      isActiveToday: false,
      isInGrace: false,
      lastObservationDate: lastObsDate,
    );
  }

  // Compte les jours consécutifs depuis la plus récente avec tolérance 1j
  var current = 1;
  for (var i = 1; i < obsDays.length; i++) {
    final gap = obsDays[i - 1].difference(obsDays[i]).inDays;
    if (gap <= 2) {
      // gap == 1 → jours consécutifs, gap == 2 → un jour sauté toléré
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

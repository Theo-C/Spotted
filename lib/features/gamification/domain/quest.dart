import '../../observations/data/observations_for_map_provider.dart';

/// Quête journalière : un mini-défi qui se reset chaque jour à minuit local.
/// Reward : un bonus XP créditté une seule fois par jour quand claim.
///
/// Les quêtes sont définies en CODE (cf. allDailyQuests), pas en BDD.
/// La table `user_quest_claims` ne stocke que les claims (qui a réclamé
/// quelle quête à quelle date), pour éviter de re-créditer.
class Quest {
  const Quest({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.progressFn,
  });

  /// Slug stable utilisé en clé DB (user_quest_claims.quest_id).
  final String id;

  final String name;
  final String description;
  final String icon;

  /// XP bonus crédité une fois la quête claim.
  final int xpReward;

  /// Calcule la progression de l'user sur la quête pour AUJOURD'HUI.
  /// Retourne 0..1 + label optionnel.
  final QuestProgress Function(QuestContext ctx) progressFn;
}

class QuestContext {
  const QuestContext({required this.todayObservations});

  /// Observations de l'user faites aujourd'hui (date locale, après minuit).
  final List<ObservationOnMap> todayObservations;
}

class QuestProgress {
  const QuestProgress({required this.value, this.label});

  final double value;
  final String? label;
}

/// État runtime d'une quête : sa définition + sa progression + son état
/// claim (true si l'XP a déjà été crédité aujourd'hui).
class QuestStatus {
  const QuestStatus({
    required this.def,
    required this.progress,
    required this.claimed,
  });

  final Quest def;
  final QuestProgress progress;

  /// True si le user a déjà claim le bonus aujourd'hui.
  final bool claimed;

  /// True si la quête est complète mais pas encore claim.
  bool get isClaimable => progress.value >= 1.0 && !claimed;
}

// =============================================================
// Définitions des quêtes journalières (source de vérité)
// =============================================================

const List<Quest> allDailyQuests = [
  Quest(
    id: 'daily_one_obs',
    name: 'Sortie du jour',
    description: 'Fais au moins 1 observation aujourd\'hui.',
    icon: '🌿',
    xpReward: 20,
    progressFn: _oneObsToday,
  ),
  Quest(
    id: 'daily_one_photo',
    name: 'Coup d\'œil photo',
    description: 'Joins une photo à une obs aujourd\'hui.',
    icon: '📸',
    xpReward: 30,
    progressFn: _onePhotoToday,
  ),
  Quest(
    id: 'daily_two_species',
    name: 'Double trouvaille',
    description: 'Observe 2 espèces différentes aujourd\'hui.',
    icon: '🎯',
    xpReward: 40,
    progressFn: _twoSpeciesToday,
  ),
];

// =============================================================
// Fonctions de progression
// =============================================================

QuestProgress _oneObsToday(QuestContext ctx) {
  final n = ctx.todayObservations.length;
  return QuestProgress(
    value: n >= 1 ? 1.0 : 0.0,
    label: '$n / 1 obs',
  );
}

QuestProgress _onePhotoToday(QuestContext ctx) {
  final n = ctx.todayObservations.where((o) => o.obs.photoUrl != null).length;
  return QuestProgress(
    value: n >= 1 ? 1.0 : 0.0,
    label: '$n / 1 photo',
  );
}

QuestProgress _twoSpeciesToday(QuestContext ctx) {
  final distinct =
      ctx.todayObservations.map((o) => o.obs.speciesId).toSet().length;
  return QuestProgress(
    value: (distinct / 2).clamp(0.0, 1.0),
    label: '$distinct / 2 espèces',
  );
}

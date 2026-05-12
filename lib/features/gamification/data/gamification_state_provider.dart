import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../observations/data/observations_for_map_provider.dart';
import '../domain/badge.dart';
import '../domain/quest.dart';
import '../domain/streak.dart';
import 'user_badges_repository.dart';
import 'user_quest_claims_repository.dart';

/// Observations du user authentifié uniquement (filtre côté client depuis
/// allObservationsForMapProvider qui est partagé). Source de vérité pour
/// série, badges, quêtes.
final _myObservationsProvider =
    Provider<List<ObservationOnMap>>((ref) {
  final all = ref.watch(allObservationsForMapProvider).asData?.value ?? const [];
  final userId = ref.watch(currentAuthUserProvider)?.id;
  if (userId == null) return const [];
  return all.where((i) => i.obs.userId == userId).toList();
});

/// Série actuelle de l'user (calculée depuis ses observations).
final streakProvider = Provider<Streak>((ref) {
  final myObs = ref.watch(_myObservationsProvider);
  return computeStreak(myObs.map((i) => i.obs).toList());
});

/// État des badges : pour chaque BadgeDef, sa progression et s'il est earned
/// (présent en BDD user_badges). Auto-déclenche un INSERT en BDD pour les
/// badges qui viennent d'atteindre 100% (effet de bord contrôlé).
final badgesProvider = FutureProvider<List<BadgeStatus>>((ref) async {
  final myObs = ref.watch(_myObservationsProvider);
  final streak = ref.watch(streakProvider);
  final userId = ref.watch(currentAuthUserProvider)?.id;
  if (userId == null) return const [];

  // Chargement des badges déjà unlockés en BDD
  final repo = ref.read(userBadgesRepositoryProvider);
  final earnedList = await repo.getEarnedForUser(userId);
  final earnedById = {for (final e in earnedList) e.badgeId: e};

  final ctx = BadgeContext(observations: myObs, streak: streak);

  // Calcul de la progression pour chaque badge défini
  final statuses = <BadgeStatus>[];
  for (final def in allBadges) {
    final progress = def.progressFn(ctx);
    final earned = earnedById[def.id];
    statuses.add(BadgeStatus(
      def: def,
      progress: progress,
      earnedAt: earned?.earnedAt,
    ));
  }

  // Détection auto des unlocks : tout badge complété (progress >= 1.0) qui
  // n'est pas encore en BDD → on l'insère. La 1ʳᵉ insertion = trigger
  // animation côté UI (cf. newlyEarnedBadgesProvider qui watch les diffs).
  for (final s in statuses) {
    if (s.isPendingUnlock) {
      await repo.insertEarned(userId: userId, badgeId: s.def.id);
    }
  }

  return statuses;
});

/// Quêtes du jour : pour chaque quête définie, sa progression et son état claim.
final dailyQuestsProvider = FutureProvider<List<QuestStatus>>((ref) async {
  final userId = ref.watch(currentAuthUserProvider)?.id;
  if (userId == null) return const [];

  final myObs = ref.watch(_myObservationsProvider);
  final today = _today();
  final todayObs = myObs.where((i) => _sameDay(i.obs.observedAt, today)).toList();

  final claims = await ref
      .read(userQuestClaimsRepositoryProvider)
      .getTodayClaims(userId: userId, today: today);
  final claimedIds = claims.map((c) => c.questId).toSet();

  final ctx = QuestContext(todayObservations: todayObs);
  return [
    for (final q in allDailyQuests)
      QuestStatus(
        def: q,
        progress: q.progressFn(ctx),
        claimed: claimedIds.contains(q.id),
      ),
  ];
});

/// Claim une quête : insert le claim en BDD (idempotent), retourne le XP crédité.
/// L'UI appelle ça quand l'user tape sur "Réclamer" sur une quête complète.
final questClaimerProvider =
    Provider<Future<int> Function(Quest)>((ref) {
  return (Quest quest) async {
    final userId = ref.read(currentAuthUserProvider)?.id;
    if (userId == null) return 0;
    final today = _today();
    await ref.read(userQuestClaimsRepositoryProvider).insertClaim(
          userId: userId,
          questId: quest.id,
          claimDate: today,
          xpCredited: quest.xpReward,
        );
    ref.invalidate(dailyQuestsProvider);
    return quest.xpReward;
  };
});

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

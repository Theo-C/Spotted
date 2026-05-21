import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider est sous legacy.dart en Riverpod 3 — équivalent simple
// d'un StateNotifier sans classe dédiée. Pour la file de célébrations
// c'est largement suffisant.
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/data/auth_providers.dart';
import '../../observations/data/observations_for_map_provider.dart';
import '../domain/badge.dart';
import '../domain/quest.dart';
import '../domain/streak.dart';
import 'gamification_providers.dart';
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

/// File d'attente des badges à célébrer côté UI. Alimentée par badgesProvider
/// au moment de l'INSERT (auto-unlock), consommée par BadgeUnlockOverlay
/// qui pop la 1ʳᵉ entrée et la célèbre. Reset à chaque restart d'app —
/// pour le MVP on accepte qu'un badge gagné juste avant un crash ne soit
/// pas re-célébré ; l'enregistrement BDD est persistant.
///
/// Pourquoi une file séparée plutôt qu'un diff côté UI : le diff fragile
/// rate les célébrations quand la même run d'badgesProvider INSERT en BDD
/// ET retourne (avec un earnedAt déjà null car lu avant l'INSERT) →
/// l'overlay voyait earnedNow={} et ratait l'unlock. La file rend l'intention
/// explicite : "ce badge vient d'être unlocked, célèbre-le".
final pendingBadgeCelebrationsProvider =
    StateProvider<List<String>>((_) => []);

/// État des badges : pour chaque BadgeDef, sa progression et s'il est earned
/// (présent en BDD user_badges). Auto-déclenche un INSERT en BDD pour les
/// badges qui viennent d'atteindre 100% + pousse l'ID dans la file de
/// célébrations.
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
  final newlyUnlockedIds = <String>[];

  // Calcul de la progression + auto-unlock pour chaque badge défini.
  final statuses = <BadgeStatus>[];
  for (final def in allBadges) {
    final progress = def.progressFn(ctx);
    final earned = earnedById[def.id];
    DateTime? earnedAt = earned?.earnedAt;

    // Auto-unlock : progression complète mais pas encore en BDD → INSERT,
    // et on marque earnedAt en mémoire pour que cette même run renvoie un
    // statut cohérent (avant ce fix, earnedAt restait null et l'overlay
    // ratait la transition → célébration différée au prochain rebuild,
    // souvent au mauvais moment).
    if (earnedAt == null && progress.value >= 1.0) {
      await repo.insertEarned(userId: userId, badgeId: def.id);
      earnedAt = DateTime.now();
      newlyUnlockedIds.add(def.id);
    }

    statuses.add(BadgeStatus(
      def: def,
      progress: progress,
      earnedAt: earnedAt,
    ));
  }

  // Pousse les nouveaux unlocks dans la file de célébration via microtask
  // pour ne pas muter d'autre state pendant la résolution du Future.
  if (newlyUnlockedIds.isNotEmpty) {
    Future.microtask(() {
      final notifier = ref.read(pendingBadgeCelebrationsProvider.notifier);
      final current = notifier.state;
      final additions =
          newlyUnlockedIds.where((id) => !current.contains(id)).toList();
      if (additions.isNotEmpty) {
        notifier.state = [...current, ...additions];
      }
    });
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
    // Rafraîchit les quêtes (l'item passe à claimed) ET le total points / level
    // (sinon la barre XP de la home ne bouge pas — bug constaté 2026-05-15).
    ref.invalidate(dailyQuestsProvider);
    ref.invalidate(accountTotalPointsProvider);
    ref.invalidate(accountLevelProvider);
    return quest.xpReward;
  };
});

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

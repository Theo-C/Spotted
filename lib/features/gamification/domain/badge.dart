import '../../../shared/models/rarity.dart';
import '../../observations/data/observations_for_map_provider.dart';
import 'streak.dart';

/// Catégorisation des badges pour le groupage UI (Profil → grille badges).
enum BadgeCategory {
  /// Premiers pas + cap d'espèces (1ʳᵉ obs, 10 espèces, 25 espèces…).
  firstSteps,

  /// Rareté (1 obs épique, 1 obs légendaire, 5 légendaires…).
  rarity,

  /// Photographe (10 obs avec photo, 50 avec photo).
  photo,

  /// Paliers de série (J7, J30, J100, J365).
  streak,
}

/// Définition d'un badge. Les badges sont définis en CODE (cf. allBadges plus
/// bas), pas en BDD. Les seuls éléments stockés en DB sont les unlocks
/// (table `user_badges` : user_id, badge_id, earned_at).
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.progressFn,
  });

  /// Slug stable utilisé en clé DB (user_badges.badge_id). Ne JAMAIS
  /// changer après release sinon les unlocks existants pointent dans le vide.
  final String id;

  /// Nom court affiché sous l'icône dans la grille.
  final String name;

  /// Phrase descriptive : "Comment l'obtenir" / "À quoi ça correspond".
  final String description;

  /// Emoji ou icône (string court).
  final String icon;

  final BadgeCategory category;

  /// Calcule la progression de l'user vers ce badge (0.0 → 1.0).
  /// Le badge est considéré comme méritant un unlock dès que progress >= 1.0.
  /// Retourne aussi un label humain optionnel ("7/10 espèces", "0/100 jours"…).
  final BadgeProgress Function(BadgeContext ctx) progressFn;
}

/// Contexte fourni aux fonctions de progression : tout ce qu'elles peuvent
/// utiliser pour décider si le badge est mérité.
class BadgeContext {
  const BadgeContext({
    required this.observations,
    required this.streak,
  });

  /// Toutes les observations de l'user courant, enrichies de species/rarity.
  final List<ObservationOnMap> observations;

  /// Série actuelle de l'user.
  final Streak streak;
}

/// État d'avancement vers un badge.
class BadgeProgress {
  const BadgeProgress({required this.value, this.label});

  /// Progression 0..1. Ouvert quand >= 1.0.
  final double value;

  /// Label humain optionnel ("3/10 espèces"). Si null, la barre seule s'affiche.
  final String? label;
}

/// Le badge tel que consommé par l'UI : sa définition + son état runtime
/// (unlock date si débloqué, sinon progression vers le déblocage).
class BadgeStatus {
  const BadgeStatus({
    required this.def,
    required this.progress,
    this.earnedAt,
  });

  final BadgeDef def;
  final BadgeProgress progress;
  final DateTime? earnedAt;

  bool get isEarned => earnedAt != null;

  /// True si l'user remplit les conditions du badge MAIS ne l'a pas encore
  /// dans la table user_badges (= à insérer + animation à montrer).
  bool get isPendingUnlock => !isEarned && progress.value >= 1.0;
}

// =============================================================
// Définitions des badges (source de vérité)
// =============================================================

/// Liste complète des badges du système. Ordre = ordre d'affichage UI.
const List<BadgeDef> allBadges = [
  // ===== FIRST STEPS — cap espèces =====
  BadgeDef(
    id: 'first_obs',
    name: 'Première observation',
    description: 'Valide ta toute première obs.',
    icon: '🐣',
    category: BadgeCategory.firstSteps,
    progressFn: _firstObs,
  ),
  BadgeDef(
    id: 'ten_species',
    name: '10 espèces',
    description: 'Observe 10 espèces différentes.',
    icon: '🐾',
    category: BadgeCategory.firstSteps,
    progressFn: _speciesCount10,
  ),
  BadgeDef(
    id: 'twenty_five_species',
    name: '25 espèces',
    description: 'Observe 25 espèces différentes.',
    icon: '📔',
    category: BadgeCategory.firstSteps,
    progressFn: _speciesCount25,
  ),
  BadgeDef(
    id: 'fifty_species',
    name: '50 espèces',
    description: 'Observe 50 espèces différentes.',
    icon: '📚',
    category: BadgeCategory.firstSteps,
    progressFn: _speciesCount50,
  ),

  // ===== RARITY =====
  BadgeDef(
    id: 'first_epic',
    name: 'Premier épique',
    description: 'Observe une espèce épique.',
    icon: '⚡',
    category: BadgeCategory.rarity,
    progressFn: _firstEpic,
  ),
  BadgeDef(
    id: 'first_legendary',
    name: 'Premier légendaire',
    description: 'Observe une espèce légendaire.',
    icon: '🌟',
    category: BadgeCategory.rarity,
    progressFn: _firstLegendary,
  ),
  BadgeDef(
    id: 'five_legendary',
    name: 'Cinq légendaires',
    description: 'Observe 5 espèces légendaires différentes.',
    icon: '👑',
    category: BadgeCategory.rarity,
    progressFn: _fiveLegendary,
  ),

  // ===== PHOTO =====
  BadgeDef(
    id: 'photo_ten',
    name: 'Premières photos',
    description: 'Joins une photo à 10 observations.',
    icon: '📸',
    category: BadgeCategory.photo,
    progressFn: _photo10,
  ),
  BadgeDef(
    id: 'photo_fifty',
    name: 'Photographe',
    description: 'Joins une photo à 50 observations.',
    icon: '🎞️',
    category: BadgeCategory.photo,
    progressFn: _photo50,
  ),

  // ===== STREAK (paliers série) =====
  BadgeDef(
    id: 'streak_7',
    name: 'Une semaine',
    description: 'Tiens une série de 7 jours.',
    icon: '🔥',
    category: BadgeCategory.streak,
    progressFn: _streak7,
  ),
  BadgeDef(
    id: 'streak_30',
    name: 'Pisteur du mois',
    description: 'Tiens une série de 30 jours.',
    icon: '🦊',
    category: BadgeCategory.streak,
    progressFn: _streak30,
  ),
  BadgeDef(
    id: 'streak_100',
    name: 'Centurion',
    description: 'Tiens une série de 100 jours.',
    icon: '🏛',
    category: BadgeCategory.streak,
    progressFn: _streak100,
  ),
  BadgeDef(
    id: 'streak_365',
    name: 'Année complète',
    description: 'Tiens une série de 365 jours.',
    icon: '🐢',
    category: BadgeCategory.streak,
    progressFn: _streak365,
  ),
];

// =============================================================
// Fonctions de progression (privées, top-level pour pouvoir être const)
// =============================================================

BadgeProgress _firstObs(BadgeContext ctx) {
  final n = ctx.observations.length;
  return BadgeProgress(
    value: n >= 1 ? 1.0 : 0.0,
    label: n >= 1 ? null : 'Aucune obs pour l\'instant',
  );
}

BadgeProgress _speciesCountN(BadgeContext ctx, int target) {
  final distinct = ctx.observations.map((o) => o.obs.speciesId).toSet().length;
  return BadgeProgress(
    value: (distinct / target).clamp(0.0, 1.0),
    label: '$distinct / $target espèces',
  );
}

BadgeProgress _speciesCount10(BadgeContext ctx) => _speciesCountN(ctx, 10);
BadgeProgress _speciesCount25(BadgeContext ctx) => _speciesCountN(ctx, 25);
BadgeProgress _speciesCount50(BadgeContext ctx) => _speciesCountN(ctx, 50);

BadgeProgress _firstEpic(BadgeContext ctx) {
  final hasEpic = ctx.observations.any((o) => o.rarity == Rarity.epic);
  return BadgeProgress(
    value: hasEpic ? 1.0 : 0.0,
    label: hasEpic ? null : 'À débusquer',
  );
}

BadgeProgress _firstLegendary(BadgeContext ctx) {
  final hasLeg = ctx.observations.any((o) => o.rarity == Rarity.legendary);
  return BadgeProgress(
    value: hasLeg ? 1.0 : 0.0,
    label: hasLeg ? null : 'À débusquer',
  );
}

BadgeProgress _fiveLegendary(BadgeContext ctx) {
  final n = ctx.observations
      .where((o) => o.rarity == Rarity.legendary)
      .map((o) => o.obs.speciesId)
      .toSet()
      .length;
  return BadgeProgress(
    value: (n / 5).clamp(0.0, 1.0),
    label: '$n / 5 légendaires',
  );
}

BadgeProgress _photoN(BadgeContext ctx, int target) {
  final n = ctx.observations.where((o) => o.obs.photoUrl != null).length;
  return BadgeProgress(
    value: (n / target).clamp(0.0, 1.0),
    label: '$n / $target avec photo',
  );
}

BadgeProgress _photo10(BadgeContext ctx) => _photoN(ctx, 10);
BadgeProgress _photo50(BadgeContext ctx) => _photoN(ctx, 50);

BadgeProgress _streakN(BadgeContext ctx, int target) {
  final n = ctx.streak.longest;
  return BadgeProgress(
    value: (n / target).clamp(0.0, 1.0),
    label: n >= target ? null : 'Record : $n / $target jours',
  );
}

BadgeProgress _streak7(BadgeContext ctx) => _streakN(ctx, 7);
BadgeProgress _streak30(BadgeContext ctx) => _streakN(ctx, 30);
BadgeProgress _streak100(BadgeContext ctx) => _streakN(ctx, 100);
BadgeProgress _streak365(BadgeContext ctx) => _streakN(ctx, 365);

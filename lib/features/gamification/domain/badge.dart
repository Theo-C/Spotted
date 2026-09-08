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

  /// Collections thématiques (mésanges, pics, corvidés…).
  collection,

  /// Badges secrets — description masquée tant qu'ils ne sont pas débloqués.
  mystery,
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
    this.isHidden = false,
    this.hiddenIcon,
    this.hiddenHint,
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

  /// Badge mystère : tant qu'il n'est pas débloqué, l'UI masque nom, icône
  /// et description. La condition ne doit pas être devinable depuis la fiche
  /// — sinon c'est un badge normal.
  final bool isHidden;

  /// Icône affichée à la place de [icon] tant que le badge mystère est
  /// verrouillé. Choisir un emoji "atmosphérique" qui donne du flavor
  /// sans révéler la condition (ex: 🌒 pour un badge nocturne).
  final String? hiddenIcon;

  /// Phrase cryptique affichée à la place du nom/description tant que le
  /// badge mystère est verrouillé (ex: "L'heure des chasseurs silencieux").
  final String? hiddenHint;

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

  // ===== COLLECTIONS =====
  // Comptage par matching sur le commonName (case-insensitive, sans accents).
  // Les seuils sont volontairement bas pour rester atteignables au MVP Oise
  // sans avoir la collection complète — ajuster quand le catalogue grandit.
  BadgeDef(
    id: 'gang_mesanges',
    name: 'Chef du gang des mésanges',
    description: 'Observe 4 espèces différentes de mésanges.',
    icon: '🐦',
    category: BadgeCategory.collection,
    progressFn: _gangMesanges,
  ),
  BadgeDef(
    id: 'casse_bois',
    name: 'Casse-bois',
    description: 'Observe 3 espèces différentes de pics.',
    icon: '🪵',
    category: BadgeCategory.collection,
    progressFn: _casseBois,
  ),
  BadgeDef(
    id: 'confrerie_noire',
    name: 'La Confrérie Noire',
    description: 'Observe 4 espèces différentes de corvidés '
        '(corneille, corbeau, pie, geai, choucas).',
    icon: '🖤',
    category: BadgeCategory.collection,
    progressFn: _confrerieNoire,
  ),
  BadgeDef(
    id: 'rapace_hunter',
    name: 'Tête de faucon',
    description: 'Observe 3 espèces différentes de rapaces diurnes '
        '(faucon, buse, milan, épervier, aigle, busard).',
    icon: '🦅',
    category: BadgeCategory.collection,
    progressFn: _rapaceHunter,
  ),
  BadgeDef(
    id: 'escadron_aquatique',
    name: 'Escadron aquatique',
    description: "Observe 3 espèces d'oiseaux d'eau "
        '(canard, sarcelle, oie, cygne, foulque, héron, aigrette).',
    icon: '🦆',
    category: BadgeCategory.collection,
    progressFn: _escadronAquatique,
  ),
  BadgeDef(
    id: 'sang_froid',
    name: 'Sang froid',
    description: 'Observe 3 reptiles différents '
        '(couleuvre, vipère, lézard, orvet).',
    icon: '🦎',
    category: BadgeCategory.collection,
    progressFn: _sangFroid,
  ),
  BadgeDef(
    id: 'prince_des_bois',
    name: 'Prince des bois',
    description: 'Observe 3 grands mammifères '
        '(cerf, chevreuil, sanglier, biche, daim).',
    icon: '🦌',
    category: BadgeCategory.collection,
    progressFn: _princeDesBois,
  ),
  BadgeDef(
    id: 'chuchoteur_ombres',
    name: "Chuchoteur d'ombres",
    description: 'Observe 2 rapaces nocturnes '
        '(chouette, hibou, effraie).',
    icon: '🦉',
    category: BadgeCategory.collection,
    progressFn: _chuchoteurOmbres,
  ),

  // ===== MYSTÈRES =====
  // Volontairement non devinables depuis la fiche : nom, icône et
  // description sont masqués tant qu'ils ne sont pas débloqués.
  // Chaque mystère a son propre `hiddenIcon` + `hiddenHint` pour un
  // teasing plus atmosphérique que "?????".
  BadgeDef(
    id: 'night_owl',
    name: 'Chouette de nuit',
    description: 'Observation entre 22h et 5h du matin.',
    icon: '🌙',
    hiddenIcon: '🌒',
    hiddenHint: 'Certains attendent que la lumière tombe…',
    category: BadgeCategory.mystery,
    isHidden: true,
    progressFn: _nightOwl,
  ),
  BadgeDef(
    id: 'dawn_call',
    name: "L'appel de l'aube",
    description: 'Observation entre 5h et 7h du matin.',
    icon: '🌅',
    hiddenIcon: '🌫️',
    hiddenHint: 'Lève-toi avant le monde…',
    category: BadgeCategory.mystery,
    isHidden: true,
    progressFn: _dawnCall,
  ),
  BadgeDef(
    id: 'rush_hour',
    name: 'Sprint naturaliste',
    description: '3 observations enregistrées en moins de 10 minutes.',
    icon: '⚡',
    hiddenIcon: '💨',
    hiddenHint: "Rapide comme l'éclair — trois fois.",
    category: BadgeCategory.mystery,
    isHidden: true,
    progressFn: _rushHour,
  ),
  BadgeDef(
    id: 'nomad',
    name: 'Nomade',
    description: 'Observations dans 3 zones différentes.',
    icon: '🗺️',
    hiddenIcon: '🧭',
    hiddenHint: 'Aucune frontière ne t\'arrête.',
    category: BadgeCategory.mystery,
    isHidden: true,
    progressFn: _nomad,
  ),
  BadgeDef(
    id: 'jackpot',
    name: 'Jackpot',
    description: '2 espèces légendaires dans la même journée.',
    icon: '🎰',
    hiddenIcon: '🎲',
    hiddenHint: 'La chance sourit — deux fois de suite ?',
    category: BadgeCategory.mystery,
    isHidden: true,
    progressFn: _jackpot,
  ),
  BadgeDef(
    id: 'grand_chelem',
    name: 'Grand chelem',
    description: 'Une observation dans chacune des 4 catégories '
        'dans la même journée.',
    icon: '🎯',
    hiddenIcon: '🃏',
    hiddenHint: 'Le règne animal ne se limite pas à une case.',
    category: BadgeCategory.mystery,
    isHidden: true,
    progressFn: _grandChelem,
  ),
  BadgeDef(
    id: 'bete_noire',
    name: 'Bête noire',
    description: 'Observe 5 fois la même espèce (obsession assumée).',
    icon: '🎭',
    hiddenIcon: '🔁',
    hiddenHint: "L'obsession commence par une répétition.",
    category: BadgeCategory.mystery,
    isHidden: true,
    progressFn: _beteNoire,
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

// -------------------------------------------------------------
// Collections — matching sur commonName (insensible à la casse/accents).
// -------------------------------------------------------------

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[àâä]'), 'a')
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[îï]'), 'i')
    .replaceAll(RegExp(r'[ôö]'), 'o')
    .replaceAll(RegExp(r'[ûüù]'), 'u')
    .replaceAll('ç', 'c');

/// Compte le nombre d'espèces distinctes dont le commonName contient un des
/// mots-clés (après normalisation).
int _distinctSpeciesMatching(BadgeContext ctx, List<String> keywords) {
  final ids = <String>{};
  for (final o in ctx.observations) {
    final name = o.species?.commonName;
    if (name == null) continue;
    final n = _normalize(name);
    if (keywords.any(n.contains)) ids.add(o.obs.speciesId);
  }
  return ids.length;
}

BadgeProgress _collectionN(
  BadgeContext ctx,
  List<String> keywords,
  int target,
  String label,
) {
  final n = _distinctSpeciesMatching(ctx, keywords);
  return BadgeProgress(
    value: (n / target).clamp(0.0, 1.0),
    label: '$n / $target $label',
  );
}

BadgeProgress _gangMesanges(BadgeContext ctx) =>
    _collectionN(ctx, ['mesange'], 4, 'mésanges');

BadgeProgress _casseBois(BadgeContext ctx) =>
    _collectionN(ctx, ['pic '], 3, 'pics');

BadgeProgress _confrerieNoire(BadgeContext ctx) => _collectionN(
      ctx,
      ['corneille', 'corbeau', 'pie', 'geai', 'choucas'],
      4,
      'corvidés',
    );

BadgeProgress _rapaceHunter(BadgeContext ctx) => _collectionN(
      ctx,
      ['faucon', 'buse', 'milan', 'epervier', 'aigle', 'busard'],
      3,
      'rapaces',
    );

BadgeProgress _escadronAquatique(BadgeContext ctx) => _collectionN(
      ctx,
      ['canard', 'sarcelle', 'oie', 'cygne', 'foulque', 'heron', 'aigrette'],
      3,
      'aquatiques',
    );

BadgeProgress _sangFroid(BadgeContext ctx) => _collectionN(
      ctx,
      ['couleuvre', 'vipere', 'lezard', 'orvet'],
      3,
      'reptiles',
    );

BadgeProgress _princeDesBois(BadgeContext ctx) => _collectionN(
      ctx,
      ['cerf', 'chevreuil', 'sanglier', 'biche', 'daim'],
      3,
      'grands mammifères',
    );

BadgeProgress _chuchoteurOmbres(BadgeContext ctx) => _collectionN(
      ctx,
      ['chouette', 'hibou', 'effraie'],
      2,
      'rapaces nocturnes',
    );

// -------------------------------------------------------------
// Mystères — pas de label pour ne pas fuiter la condition.
// -------------------------------------------------------------

BadgeProgress _nightOwl(BadgeContext ctx) {
  final hit = ctx.observations.any((o) {
    final h = o.obs.observedAt.toLocal().hour;
    return h >= 22 || h < 5;
  });
  return BadgeProgress(value: hit ? 1.0 : 0.0);
}

BadgeProgress _dawnCall(BadgeContext ctx) {
  final hit = ctx.observations.any((o) {
    final h = o.obs.observedAt.toLocal().hour;
    return h >= 5 && h < 7;
  });
  return BadgeProgress(value: hit ? 1.0 : 0.0);
}

BadgeProgress _rushHour(BadgeContext ctx) {
  if (ctx.observations.length < 3) return const BadgeProgress(value: 0.0);
  // observedAt reflète le moment de la scène (EXIF), pas de la saisie —
  // on utilise createdAt côté BDD si dispo dans le modèle, sinon on retombe
  // sur observedAt. La condition "3 en 10 min" reste sémantiquement OK.
  final times = ctx.observations
      .map((o) => o.obs.observedAt.millisecondsSinceEpoch)
      .toList()
    ..sort();
  for (var i = 0; i <= times.length - 3; i++) {
    if (times[i + 2] - times[i] <= 10 * 60 * 1000) {
      return const BadgeProgress(value: 1.0);
    }
  }
  return const BadgeProgress(value: 0.0);
}

BadgeProgress _nomad(BadgeContext ctx) {
  final zones = ctx.observations
      .map((o) => o.obs.zoneId)
      .whereType<String>()
      .toSet();
  return BadgeProgress(value: (zones.length / 3).clamp(0.0, 1.0));
}

BadgeProgress _jackpot(BadgeContext ctx) {
  final legByDay = <String, Set<String>>{};
  for (final o in ctx.observations) {
    if (o.rarity != Rarity.legendary) continue;
    final d = o.obs.observedAt.toLocal();
    final key = '${d.year}-${d.month}-${d.day}';
    legByDay.putIfAbsent(key, () => {}).add(o.obs.speciesId);
  }
  final hit = legByDay.values.any((s) => s.length >= 2);
  return BadgeProgress(value: hit ? 1.0 : 0.0);
}

BadgeProgress _grandChelem(BadgeContext ctx) {
  // On group par jour, puis on regarde si les 4 catégories sont couvertes.
  // categoryId absent (species null) → obs ignorée.
  final byDay = <String, Set<String>>{};
  for (final o in ctx.observations) {
    final cat = o.species?.categoryId;
    if (cat == null) continue;
    final d = o.obs.observedAt.toLocal();
    final key = '${d.year}-${d.month}-${d.day}';
    byDay.putIfAbsent(key, () => {}).add(cat);
  }
  final hit = byDay.values.any((s) => s.length >= 4);
  return BadgeProgress(value: hit ? 1.0 : 0.0);
}

BadgeProgress _beteNoire(BadgeContext ctx) {
  final counts = <String, int>{};
  for (final o in ctx.observations) {
    counts[o.obs.speciesId] = (counts[o.obs.speciesId] ?? 0) + 1;
  }
  final hit = counts.values.any((c) => c >= 5);
  return BadgeProgress(value: hit ? 1.0 : 0.0);
}

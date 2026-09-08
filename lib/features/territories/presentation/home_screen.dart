import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/zone.dart';
import '../../auth/data/auth_providers.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/data/gamification_state_provider.dart';
import '../../gamification/domain/level.dart';
import '../../gamification/domain/streak.dart';
import '../../gamification/presentation/badge_unlock_overlay.dart';
import '../../gamification/presentation/daily_quests_section.dart';
import '../../gamification/presentation/daily_species_banner.dart';
import '../../gamification/presentation/level_up_overlay.dart';
import '../../observations/presentation/recent_observations_section.dart';
import '../data/territory_progress_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: LevelUpOverlay(
        child: BadgeUnlockOverlay(
          child: SafeArea(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 14),
                _ProgressHeader(
                  levelAsync: ref.watch(accountLevelProvider),
                  streak: ref.watch(streakProvider),
                ),
                const SizedBox(height: 12),
                const DailyQuestsSection(),
                const SizedBox(height: 16),
                const DailySpeciesBanner(),
                const SizedBox(height: 20),
                const RecentObservationsSection(),
                const SizedBox(height: 20),
                const _SectionLabel(text: 'Mes terrains'),
                const SizedBox(height: 8),
                _TerritoriesList(zonesAsync: ref.watch(allZonesProvider)),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// _Header — titre app + bouton +
// =============================================================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARNET NATURALISTE',
                  style: GoogleFonts.karla(
                    fontSize: 11,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                    color: terracotta,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Spotted',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    color: forestGreen,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: forestGreen,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _showAddMenu(context),
              child: const SizedBox(
                // 48×48 minimum pour la cible tactile Material (vs 36 avant).
                width: 48,
                height: 48,
                child: Icon(Icons.add, color: surfaceBase, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAddMenu(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: surfaceBase,
    useRootNavigator: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E0CE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            _AddMenuTile(
              icon: Icons.add_a_photo_outlined,
              label: 'Nouvelle observation',
              subtitle: 'Saisis une obs depuis une photo',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/observation/new');
              },
            ),
            // Gate admin — l'ajout au catalogue est réservé (curation
            // éditoriale, pas de contribution libre). Consumer local pour
            // éviter de propager ref jusqu'ici.
            Consumer(
              builder: (context, ref, _) {
                if (!ref.watch(isAdminProvider)) return const SizedBox.shrink();
                return _AddMenuTile(
                  icon: Icons.pets,
                  label: 'Nouvelle espèce',
                  subtitle: 'Ajoute une espèce au catalogue',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/species/new');
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddMenuTile extends StatelessWidget {
  const _AddMenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: forestGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: forestGreen, size: 22),
      ),
      title: Text(
        label,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: forestGreen,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.karla(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: textSecondary),
      onTap: onTap,
    );
  }
}

// =============================================================
// _ProgressHeader — fusion Niveau + Streak en une seule carte
// =============================================================
//
// v5 affichait 2 cartes séparées (StreakCard + _LevelCard) qui se faisaient
// concurrence visuellement et bouffaient ~200 px. Ici une seule carte
// gradient forestGreen avec :
//   - Pastille de niveau + label "Niveau N" + barre de progression XP
//   - Bloc streak à droite : flamme animée + nb de jours + multiplier
//     (séparés du reste par un séparateur vertical fin)
//
// Cas vides gérés silencieusement (streak = 0 → flamme grise muette,
// pas de bloc multiplier).

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.levelAsync, required this.streak});

  final AsyncValue<LevelInfo> levelAsync;
  final Streak streak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [forestGreen, forestGreenLight, forestGreen],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: forestGreen.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: levelAsync.when(
          loading: () => const SizedBox(
            height: 76,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: gold),
            ),
          ),
          error: (e, _) => Text(
            'Progression indisponible',
            style: GoogleFonts.karla(color: surfaceBase, fontSize: 13),
          ),
          data: (level) => Row(
            children: [
              Expanded(child: _LevelBlock(level: level)),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 56,
                color: surfaceBase.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 10),
              _StreakBlock(streak: streak),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBlock extends StatelessWidget {
  const _LevelBlock({required this.level});

  final LevelInfo level;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [goldLight, gold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: goldLight.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${level.value}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NIVEAU ${level.value}',
                    style: GoogleFonts.karla(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: const Color(0xFFC4A572),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Compteur de points avec tween fluide entre les valeurs
                  // successives. Quand le user réclame une quête, on voit
                  // les points monter au lieu d'un saut brutal.
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: level.currentPoints.toDouble(),
                      end: level.currentPoints.toDouble(),
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, _) => Text(
                      '${_formatPoints(value.round())} / ${_formatPoints(level.nextThreshold)} pts',
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: surfaceBase,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Barre XP avec tween fluide entre les fractions successives.
        // ValueKey sur le niveau : au passage de niveau, la barre se reset
        // (nouvelle instance) au lieu d'interpoler de 96% → 4% en marche
        // arrière. La célébration LevelUp dans l'overlay prend le relais.
        TweenAnimationBuilder<double>(
          key: ValueKey(level.value),
          tween: Tween(begin: level.progressFraction, end: level.progressFraction),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: forestGreen.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation<Color>(goldLight),
            ),
          ),
        ),
      ],
    );
  }

  String _formatPoints(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class _StreakBlock extends StatelessWidget {
  const _StreakBlock({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final isActive = streak.isActiveToday;
    final isGrace = streak.isInGrace;
    final isPaused = streak.isPaused;
    // 4 états visuels :
    //   - série brisée (current 0) : flamme grise muette
    //   - en pause (avant-hier obs, rattrapable) : flamme bleue
    //   - en grâce (hier obs, pas aujourd'hui) : flamme orange
    //   - active (obs aujourd'hui) : flamme terracotta + pulse
    final flameColor = streak.current == 0
        ? textMuted
        : isPaused
            ? const Color(0xFF4A90B8)
            : isGrace
                ? const Color(0xFFE08E2C)
                : terracotta;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Flame(color: flameColor, animated: isActive),
        const SizedBox(height: 2),
        Text(
          streak.current == 0 ? '0j' : '${streak.current}j',
          style: GoogleFonts.karla(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: surfaceBase,
            height: 1.0,
          ),
        ),
        if (streak.xpMultiplier > 1.0) ...[
          const SizedBox(height: 3),
          Text(
            '×${streak.xpMultiplier.toStringAsFixed(2)}',
            style: GoogleFonts.karla(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: goldLight,
            ),
          ),
        ],
      ],
    );
  }
}

/// Flamme avec petit pulse + glow quand active. Adapté de l'ancien
/// streak_card._FlameIcon mais plus compact (28 px au lieu de 50).
class _Flame extends StatefulWidget {
  const _Flame({required this.color, required this.animated});

  final Color color;
  final bool animated;

  @override
  State<_Flame> createState() => _FlameState();
}

class _FlameState extends State<_Flame> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animated) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Flame old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animated && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final scale = 1.0 + (_ctrl.value * 0.08);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceBase.withValues(alpha: 0.15),
              boxShadow: widget.animated
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.6),
                        blurRadius: 10 + _ctrl.value * 6,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: const Text('🔥', style: TextStyle(fontSize: 16)),
          ),
        );
      },
    );
  }
}

// =============================================================
// _SectionLabel — label uppercase tracking
// =============================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.karla(
          fontSize: 10,
          letterSpacing: 2.5,
          fontWeight: FontWeight.bold,
          color: textSecondary,
        ),
      ),
    );
  }
}

// =============================================================
// _TerritoriesList — hero = terrain courant (GPS), reste en compact
// =============================================================
//
// Le hero est dynamique : on prend la zone détectée par
// [currentTerritoryProvider] (GPS fresh > cache prefs > 1ʳᵉ zone par défaut).
// Les autres zones suivent en lignes compactes. Plus de tag statique
// DOMICILE/VOISIN : la position dans la liste = "où tu es maintenant".

class _TerritoriesList extends ConsumerWidget {
  const _TerritoriesList({required this.zonesAsync});

  final AsyncValue<List<Zone>> zonesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(currentTerritoryProvider);
    return zonesAsync.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: forestGreen),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Terrains indisponibles',
          style: GoogleFonts.karla(color: textMuted),
        ),
      ),
      data: (zones) {
        if (zones.isEmpty) return const SizedBox.shrink();
        // Hero = la zone "ici" si résolue, sinon par défaut la 1ʳᵉ de la liste.
        // currentAsync peut être en loading le temps du round-trip GPS+geocode.
        final current = currentAsync.asData?.value;
        final heroZone = current?.zone ?? zones.first;
        final heroFromGps = current?.fromGps ?? false;
        final others =
            zones.where((z) => z.id != heroZone.id).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TerritoryHero(
              zone: heroZone,
              fromGps: heroFromGps,
              progressAsync:
                  ref.watch(zoneProgressProvider(heroZone.shortCode ?? '')),
            ),
            // Scroll horizontal pour les autres territoires — footprint
            // constant même quand la liste grandit (curation d'autres
            // départements à venir). Masqué si un seul territoire configuré.
            if (others.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _OthersLabel(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: others.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _TerritoryCardCompact(
                    zone: others[i],
                    progressAsync: ref
                        .watch(zoneProgressProvider(others[i].shortCode ?? '')),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Pastille forestGreen + numéro doré. Future-proof : on pourra brancher un
/// drapeau (📍🇨🇷) ou une icône custom selon le type de zone.
class _TerritoryBadge extends StatelessWidget {
  const _TerritoryBadge({required this.code, this.size = 36});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isLong = code.length >= 3;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [forestGreen, forestGreenLight],
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: GoogleFonts.cormorantGaramond(
          fontSize: isLong ? size * 0.36 : size * 0.46,
          fontWeight: FontWeight.bold,
          color: goldLight,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Hero card pour le terrain principal — fond crème + bordure forestGreen,
/// style "page de carnet". Volontairement différent du _ProgressHeader (qui
/// est un gradient sombre) pour ne pas faire confusion entre "ma progression"
/// (gamification) et "mes terrains" (objet d'exploration).
///
/// [fromGps] = true affiche un indicateur "📍 ICI" pour faire comprendre à
/// l'user que ce terrain est en hero parce qu'il y est physiquement (vs
/// fallback éditorial).
class _TerritoryHero extends StatelessWidget {
  const _TerritoryHero({
    required this.zone,
    required this.fromGps,
    required this.progressAsync,
  });

  final Zone zone;
  final bool fromGps;
  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.go('/territory/${zone.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: forestGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: forestGreen.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TerritoryBadge(code: zone.shortCode ?? '?', size: 56),
                    const Spacer(),
                    if (fromGps) const _HerePill(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  zone.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: forestGreen,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                _TerritoryHeroProgress(progressAsync: progressAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Petit indicateur "📍 ICI" affiché sur le hero quand la position vient
/// d'une vraie lecture GPS (et pas du fallback par défaut). Aide l'user à
/// comprendre pourquoi tel ou tel terrain est mis en avant.
class _HerePill extends StatelessWidget {
  const _HerePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: terracotta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 11, color: surfaceBase),
          const SizedBox(width: 3),
          Text(
            'ICI',
            style: GoogleFonts.karla(
              fontSize: 9,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: surfaceBase,
            ),
          ),
        ],
      ),
    );
  }
}

class _TerritoryHeroProgress extends StatelessWidget {
  const _TerritoryHeroProgress({required this.progressAsync});

  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    return progressAsync.when(
      loading: () => const SizedBox(
        height: 22,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: terracotta),
          ),
        ),
      ),
      error: (_, _) => Text(
        'Progression indisponible',
        style: GoogleFonts.karla(color: textMuted, fontSize: 12),
      ),
      data: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.fraction,
              minHeight: 6,
              backgroundColor: forestGreen.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(terracotta),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${p.observed} espèces vues',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: forestGreen,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'sur ${p.total}',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  color: textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${(p.fraction * 100).round()}%',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: terracotta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Petit label discret au-dessus du scroll horizontal des autres terrains.
/// Volontairement moins fort que le titre "Mes terrains" en haut pour ne pas
/// concurrencer visuellement le hero.
class _OthersLabel extends StatelessWidget {
  const _OthersLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'AUTRES TERRAINS',
      style: GoogleFonts.karla(
        fontSize: 9,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
        color: textMuted,
      ),
    );
  }
}

/// Carte compacte pour un terrain non-actif — affichée en scroll horizontal.
/// Footprint constant peu importe le nombre de départements curés.
class _TerritoryCardCompact extends StatelessWidget {
  const _TerritoryCardCompact({
    required this.zone,
    required this.progressAsync,
  });

  final Zone zone;
  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/territory/${zone.id}'),
        child: SizedBox(
          width: 140,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E0CE), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TerritoryBadge(code: zone.shortCode ?? '?', size: 36),
                    const Icon(Icons.chevron_right,
                        size: 16, color: forestGreen),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  zone.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: forestGreen,
                    height: 1.05,
                  ),
                ),
                const Spacer(),
                _TerritoryCardProgress(progressAsync: progressAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne "12 / 50" + barre — extrait pour éviter le when() imbriqué dans la
/// card. Loading/error dégradent silencieusement (juste la barre grise).
class _TerritoryCardProgress extends StatelessWidget {
  const _TerritoryCardProgress({required this.progressAsync});

  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    final data = progressAsync.asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: data?.fraction ?? 0,
            minHeight: 4,
            backgroundColor: forestGreen.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(terracotta),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data == null ? '…' : '${data.observed} / ${data.total}',
          style: GoogleFonts.karla(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: forestGreen,
          ),
        ),
      ],
    );
  }
}

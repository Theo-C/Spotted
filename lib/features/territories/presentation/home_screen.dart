import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/zone.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/data/gamification_state_provider.dart';
import '../../gamification/domain/level.dart';
import '../../gamification/domain/streak.dart';
import '../../gamification/presentation/badge_unlock_overlay.dart';
import '../../gamification/presentation/daily_quests_section.dart';
import '../data/territory_progress_provider.dart';

/// Config d'affichage par zone — donne le tag ("DOMICILE" / "VOISIN") et la
/// couleur de tag. À terme à passer sur la table zones (ex: `display_tag`).
const _zoneDisplay = <String, ({String tag, Color tagColor})>{
  '60': (tag: 'DOMICILE', tagColor: gold),
  '02': (tag: 'VOISIN',   tagColor: terracotta),
};

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: BadgeUnlockOverlay(
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
            _AddMenuTile(
              icon: Icons.pets,
              label: 'Nouvelle espèce',
              subtitle: 'Ajoute une espèce au catalogue',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/species/new');
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
                  Text(
                    '${_formatPoints(level.currentPoints)} / ${_formatPoints(level.nextThreshold)} pts',
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      color: surfaceBase,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: level.progressFraction,
            minHeight: 5,
            backgroundColor: forestGreen.withValues(alpha: 0.5),
            valueColor: const AlwaysStoppedAnimation<Color>(goldLight),
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
    final flameColor = streak.current == 0
        ? textMuted
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
// _TerritoriesList — itère depuis allZonesProvider (vs hard-codé)
// =============================================================

// _TerritoriesList — hero pour le 1er (DOMICILE), liste compacte pour le reste.
// Plus de mini-cartes statiques Mapbox (charge inutile + zero info actionnable).
// La pastille polymorphe (numéro département FR pour l'instant) pourra à
// terme afficher un drapeau pour les zones étrangères.

class _TerritoriesList extends ConsumerWidget {
  const _TerritoriesList({required this.zonesAsync});

  final AsyncValue<List<Zone>> zonesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return Column(
          children: [
            _TerritoryHero(
              zone: zones.first,
              progressAsync: ref.watch(
                zoneProgressProvider(zones.first.shortCode ?? ''),
              ),
            ),
            for (var i = 1; i < zones.length; i++) ...[
              const SizedBox(height: 8),
              _TerritoryRowCompact(
                zone: zones[i],
                progressAsync: ref.watch(
                  zoneProgressProvider(zones[i].shortCode ?? ''),
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

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.color, this.size = 9});

  final String tag;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: GoogleFonts.karla(
          fontSize: size,
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
          color: forestGreen,
        ),
      ),
    );
  }
}

/// Hero card pour le terrain principal (DOMICILE) — gradient forestGreen,
/// pastille XL, nom en Cormorant, barre de progression dorée + pourcentage.
class _TerritoryHero extends StatelessWidget {
  const _TerritoryHero({required this.zone, required this.progressAsync});

  final Zone zone;
  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    final display = _zoneDisplay[zone.shortCode] ??
        (tag: 'AUTRE', tagColor: textSecondary);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TerritoryBadge(
                      code: zone.shortCode ?? '?',
                      size: 56,
                    ),
                    const Spacer(),
                    _TagPill(tag: display.tag, color: display.tagColor),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  zone.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: surfaceBase,
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
            child: CircularProgressIndicator(strokeWidth: 2, color: goldLight),
          ),
        ),
      ),
      error: (_, _) => Text(
        'Progression indisponible',
        style: GoogleFonts.karla(color: surfaceBase, fontSize: 12),
      ),
      data: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.fraction,
              minHeight: 6,
              backgroundColor: surfaceBase.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(goldLight),
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
                  color: surfaceBase,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'sur ${p.total}',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  color: const Color(0xFFC4A572),
                ),
              ),
              const Spacer(),
              Text(
                '${(p.fraction * 100).round()}%',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: goldLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ligne compacte pour les terrains secondaires (VOISIN, VOYAGE…).
/// ~64 px de haut, tient à 10+ territoires sans scroll.
class _TerritoryRowCompact extends StatelessWidget {
  const _TerritoryRowCompact({required this.zone, required this.progressAsync});

  final Zone zone;
  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    final display = _zoneDisplay[zone.shortCode] ??
        (tag: 'AUTRE', tagColor: textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/territory/${zone.id}'),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E0CE), width: 1.2),
            ),
            child: Row(
              children: [
                _TerritoryBadge(code: zone.shortCode ?? '?', size: 40),
                const SizedBox(width: 12),
                Expanded(child: _TerritoryRowInfo(
                  name: zone.name,
                  tag: display.tag,
                  tagColor: display.tagColor,
                  progressAsync: progressAsync,
                )),
                const Icon(Icons.chevron_right, size: 18, color: forestGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TerritoryRowInfo extends StatelessWidget {
  const _TerritoryRowInfo({
    required this.name,
    required this.tag,
    required this.tagColor,
    required this.progressAsync,
  });

  final String name;
  final String tag;
  final Color tagColor;
  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    return progressAsync.when(
      loading: () => SizedBox(
        height: 32,
        child: Row(
          children: [
            Text(
              name,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: forestGreen,
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => Text(
        name,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: forestGreen,
        ),
      ),
      data: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: forestGreen,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _TagPill(tag: tag, color: tagColor, size: 8),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                '${p.observed}',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: forestGreen,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: p.fraction,
                    minHeight: 4,
                    backgroundColor: forestGreen.withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(terracotta),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${p.total}',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

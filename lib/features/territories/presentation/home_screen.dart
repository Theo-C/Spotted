import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/env.dart';
import '../../../shared/models/zone.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/data/gamification_state_provider.dart';
import '../../gamification/domain/level.dart';
import '../../gamification/domain/streak.dart';
import '../../gamification/presentation/badge_unlock_overlay.dart';
import '../../gamification/presentation/daily_quests_section.dart';
import '../data/territory_progress_provider.dart';

/// Config d'affichage par zone — donne le centre de la mini-carte statique,
/// le tag ("DOMICILE" / "VOISIN") et la couleur de tag. Garder en local
/// tant que ces métadonnées ne sont pas en BDD ; à terme on les passe sur
/// la table zones (ex: home_center_lat, home_center_lng, display_tag).
const _zoneDisplay = <String, ({double lat, double lng, String tag, Color tagColor})>{
  '60': (lat: 49.41, lng: 2.82, tag: 'DOMICILE', tagColor: forestGreen),
  '02': (lat: 49.45, lng: 3.62, tag: 'VOISIN',   tagColor: terracotta),
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

class _TerritoriesList extends ConsumerWidget {
  const _TerritoriesList({required this.zonesAsync});

  final AsyncValue<List<Zone>> zonesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return zonesAsync.when(
      loading: () => const SizedBox(
        height: 80,
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
      data: (zones) => Column(
        children: [
          for (var i = 0; i < zones.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _TerritoryCard(
              zone: zones[i],
              progressAsync: ref.watch(zoneProgressProvider(zones[i].shortCode ?? '')),
            ),
          ],
        ],
      ),
    );
  }
}

class _TerritoryCard extends StatelessWidget {
  const _TerritoryCard({required this.zone, required this.progressAsync});

  final Zone zone;
  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    // Récupère la config d'affichage (centre + tag). Fallback si zone inconnue
    // (ex: nouvelle zone ajoutée en BDD avant qu'on définisse sa config) :
    // centre arbitraire France + tag "AUTRE".
    final display = _zoneDisplay[zone.shortCode] ??
        (lat: 46.5, lng: 2.5, tag: 'AUTRE', tagColor: textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: forestGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: forestGreen.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/territory/${zone.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TerritoryMap(
                    centerLat: display.lat,
                    centerLng: display.lng,
                    badge: display.tag,
                    badgeColor: display.tagColor,
                  ),
                  Container(height: 2, color: const Color(0xFFE8E0CE)),
                  _TerritoryInfo(
                    displayName: zone.name,
                    shortCode: zone.shortCode ?? '',
                    progressAsync: progressAsync,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerritoryMap extends StatelessWidget {
  const _TerritoryMap({
    required this.centerLat,
    required this.centerLng,
    required this.badge,
    required this.badgeColor,
  });

  final double centerLat;
  final double centerLng;
  final String badge;
  final Color badgeColor;

  static const _zoom = 8;

  String get _staticUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/static/'
      '$centerLng,$centerLat,$_zoom/600x320@2x'
      '?access_token=${Env.mapboxAccessToken}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _staticUrl,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const _MapFallback();
            },
            errorBuilder: (_, _, _) => const _MapFallback(),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                badge,
                style: GoogleFonts.karla(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: surfaceBase,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFE7D2), Color(0xFFD8CFAE)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.terrain,
          size: 56,
          color: forestGreen.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _TerritoryInfo extends StatelessWidget {
  const _TerritoryInfo({
    required this.displayName,
    required this.shortCode,
    required this.progressAsync,
  });

  final String displayName;
  final String shortCode;
  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: progressAsync.when(
        loading: () => const _TerritoryInfoSkeleton(),
        error: (e, _) => Text(
          'Progression indisponible',
          style: GoogleFonts.karla(color: textMuted, fontSize: 13),
        ),
        data: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: forestGreen,
                      ),
                      children: [
                        TextSpan(text: '$displayName '),
                        TextSpan(
                          text: '($shortCode)',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: terracotta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: forestGreen,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${p.observed}',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.fraction,
                      minHeight: 8,
                      backgroundColor: forestGreen.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(terracotta),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${p.total}',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.remaining > 0
                  ? '${p.remaining} espèces encore à découvrir'
                  : 'Toutes les espèces de $displayName observées !',
              style: GoogleFonts.karla(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerritoryInfoSkeleton extends StatelessWidget {
  const _TerritoryInfoSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: forestGreen.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/env.dart';
import '../../../shared/models/zone.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/domain/level.dart';
import '../../gamification/presentation/badge_unlock_overlay.dart';
import '../../gamification/presentation/daily_quests_section.dart';
import '../../gamification/presentation/streak_card.dart';
import '../data/territory_progress_provider.dart';

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
                const SizedBox(height: 12),
                const StreakCard(),
                const SizedBox(height: 12),
                const DailyQuestsSection(),
                const SizedBox(height: 12),
                _LevelCard(levelAsync: ref.watch(accountLevelProvider)),
                const SizedBox(height: 20),
                const _SectionLabel(text: 'Mes terrains'),
                const SizedBox(height: 8),
                _TerritoryCard(
                  shortCode: '60',
                  displayName: 'Oise',
                  badge: 'DOMICILE',
                  badgeColor: forestGreen,
                  centerLat: 49.41,
                  centerLng: 2.82,
                  progressAsync: ref.watch(zoneProgressProvider('60')),
                  zoneAsync: ref.watch(zoneByShortCodeProvider('60')),
                ),
                const SizedBox(height: 12),
                _TerritoryCard(
                  shortCode: '02',
                  displayName: 'Aisne',
                  badge: 'VOISIN',
                  badgeColor: terracotta,
                  centerLat: 49.45,
                  centerLng: 3.62,
                  progressAsync: ref.watch(zoneProgressProvider('02')),
                  zoneAsync: ref.watch(zoneByShortCodeProvider('02')),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu d'ajout (bottom sheet) au tap du bouton + sur la home.
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
                width: 36,
                height: 36,
                child: Icon(Icons.add, color: surfaceBase, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.levelAsync});

  final AsyncValue<LevelInfo> levelAsync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              color: forestGreen.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: levelAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: gold),
            ),
          ),
          error: (e, _) => Text(
            'Niveau indisponible',
            style: GoogleFonts.karla(color: surfaceBase, fontSize: 13),
          ),
          data: (level) => _LevelContent(level: level),
        ),
      ),
    );
  }
}

class _LevelContent extends StatelessWidget {
  const _LevelContent({required this.level});

  final LevelInfo level;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
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
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${level.value}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'NIVEAU',
              style: GoogleFonts.karla(
                fontSize: 9,
                letterSpacing: 2,
                color: const Color(0xFFC4A572),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatPoints(level.currentPoints),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: surfaceBase,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '/ ${_formatPoints(level.nextThreshold)} PTS',
              style: GoogleFonts.karla(
                fontSize: 10,
                letterSpacing: 1.5,
                color: const Color(0xFFC4A572),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: level.progressFraction,
            minHeight: 6,
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
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

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

class _TerritoryCard extends StatelessWidget {
  const _TerritoryCard({
    required this.shortCode,
    required this.displayName,
    required this.badge,
    required this.badgeColor,
    required this.centerLat,
    required this.centerLng,
    required this.progressAsync,
    required this.zoneAsync,
  });

  final String shortCode;
  final String displayName;
  final String badge;
  final Color badgeColor;
  final double centerLat;
  final double centerLng;
  final AsyncValue<TerritoryProgress> progressAsync;
  final AsyncValue<Zone> zoneAsync;

  @override
  Widget build(BuildContext context) {
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
              onTap: () {
                final zone = zoneAsync.asData?.value;
                if (zone != null) context.go('/territory/${zone.id}');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TerritoryMap(
                    centerLat: centerLat,
                    centerLng: centerLng,
                    badge: badge,
                    badgeColor: badgeColor,
                  ),
                  Container(height: 2, color: const Color(0xFFE8E0CE)),
                  _TerritoryInfo(
                    displayName: displayName,
                    shortCode: shortCode,
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
            // Pendant le chargement : gradient + skeleton.
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const _MapFallback();
            },
            // En cas d'erreur réseau / quota Mapbox : même gradient en fallback.
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

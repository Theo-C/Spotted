import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../core/utils/env.dart';
import '../../../shared/models/zone.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/domain/level.dart';
import '../data/territory_progress_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 12),
              const _CameraGpsTipCard(),
              const SizedBox(height: 12),
              _LevelCard(levelAsync: ref.watch(accountLevelProvider)),
              const SizedBox(height: 20),
              const _SectionLabel(text: 'Mes terrains'),
              const SizedBox(height: 8),
              _OiseCard(
                progressAsync: ref.watch(oiseProgressProvider),
                zoneAsync: ref.watch(oiseZoneProvider),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tip dismissible affiché tant que l'user n'a pas confirmé qu'il a activé
/// l'enregistrement de la localisation dans son app caméra. Persisté local
/// via `shared_preferences` (cf. OnboardingService).
class _CameraGpsTipCard extends ConsumerWidget {
  const _CameraGpsTipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(cameraGpsTipVisibleProvider);
    return visibleAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (visible) {
        if (!visible) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gold.withValues(alpha: 0.10),
                  gold.withValues(alpha: 0.20),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gold, width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avant ta première sortie',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: forestGreen,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Active « Enregistrer la localisation » dans ton app caméra "
                        "(Open Camera, Google Camera, etc.) pour que les coordonnées "
                        "soient lues automatiquement à l'import.",
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          color: textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            await ref
                                .read(onboardingServiceProvider)
                                .markCameraGpsTipSeen();
                            ref.invalidate(cameraGpsTipVisibleProvider);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 0,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            "C'EST FAIT",
                            style: GoogleFonts.karla(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                              color: forestGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              subtitle: 'Ajoute une espèce au catalogue Oise',
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

class _OiseCard extends StatelessWidget {
  const _OiseCard({
    required this.progressAsync,
    required this.zoneAsync,
  });

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
                  _OiseMapPlaceholder(),
                  Container(height: 2, color: const Color(0xFFE8E0CE)),
                  _OiseInfo(progressAsync: progressAsync),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OiseMapPlaceholder extends StatelessWidget {
  // Centre approximatif de l'Oise + zoom département.
  static const _lat = 49.41;
  static const _lng = 2.82;
  static const _zoom = 8;

  String get _staticUrl =>
      'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/static/'
      '$_lng,$_lat,$_zoom/600x320@2x'
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
                color: forestGreen,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                'DOMICILE',
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

class _OiseInfo extends StatelessWidget {
  const _OiseInfo({required this.progressAsync});

  final AsyncValue<TerritoryProgress> progressAsync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: progressAsync.when(
        loading: () => const _OiseInfoSkeleton(),
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
                        const TextSpan(text: 'Oise '),
                        TextSpan(
                          text: '(60)',
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
                  : 'Toutes les espèces de l\'Oise observées !',
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

class _OiseInfoSkeleton extends StatelessWidget {
  const _OiseInfoSkeleton();

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

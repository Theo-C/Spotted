import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/rarity.dart';
import '../../../shared/providers/observer_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/domain/level.dart';
import '../../observations/data/observations_for_map_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelAsync = ref.watch(accountLevelProvider);
    final allObsAsync = ref.watch(allObservationsForMapProvider);
    final currentAppUser = ref.watch(currentAppUserProvider).asData?.value;
    final observersAsync = ref.watch(observersProvider);
    final currentObserverId = ref.watch(currentObserverIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LevelHeader(
              user: currentAppUser,
              levelAsync: levelAsync,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Statistiques'),
            const SizedBox(height: 8),
            _StatsGrid(allObsAsync: allObsAsync),
            const SizedBox(height: 24),
            const _SectionLabel('Qui observe en ce moment ?'),
            const SizedBox(height: 8),
            _ObserverToggle(
              observersAsync: observersAsync,
              currentObserverId: currentObserverId,
              onChanged: (id) => ref
                  .read(currentObserverIdProvider.notifier)
                  .setObserver(id),
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFE8E0CE)),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.tune,
              label: 'Réglages',
              onTap: () {
                // Placeholder — Phase 9 ou post-MVP
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bientôt')),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.logout,
              label: 'Se déconnecter',
              color: const Color(0xFFB8624A),
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceBase,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Se déconnecter ?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
        content: Text(
          'Tu pourras te reconnecter à tout moment avec ton email et mot de passe.',
          style: GoogleFonts.karla(fontSize: 13, color: textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Annuler',
              style: GoogleFonts.karla(color: textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: terracotta),
            child: Text(
              'Déconnexion',
              style: GoogleFonts.karla(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
      // go_router redirect → /login automatique via _GoRouterRefreshStream
    }
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.user, required this.levelAsync});

  final AppUser? user;
  final AsyncValue<LevelInfo> levelAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          height: 100,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: gold),
          ),
        ),
        error: (e, _) => Text(
          'Niveau indisponible',
          style: GoogleFonts.karla(color: surfaceBase, fontSize: 13),
        ),
        data: (level) => _LevelContent(user: user, level: level),
      ),
    );
  }
}

class _LevelContent extends StatelessWidget {
  const _LevelContent({required this.user, required this.level});

  final AppUser? user;
  final LevelInfo level;

  @override
  Widget build(BuildContext context) {
    final accent = user?.colorAccent != null
        ? Color(int.parse(user!.colorAccent.replaceFirst('#', '0xFF')))
        : terracotta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
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
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${level.value}',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIVEAU ${level.value}',
                    style: GoogleFonts.karla(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: const Color(0xFFC4A572),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.pseudo ?? 'Compte partagé',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: surfaceBase,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatPoints(level.currentPoints),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 36,
                fontWeight: FontWeight.w300,
                color: surfaceBase,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '/ ${_formatPoints(level.nextThreshold)} PTS',
              style: GoogleFonts.karla(
                fontSize: 11,
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
        const SizedBox(height: 6),
        Text(
          'Plus que ${level.pointsToNext} pts pour le niveau ${level.value + 1}',
          style: GoogleFonts.karla(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFC4A572),
          ),
        ),
      ],
    );
  }

  static String _formatPoints(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.karla(
        fontSize: 10,
        letterSpacing: 2.5,
        fontWeight: FontWeight.bold,
        color: textSecondary,
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.allObsAsync});

  final AsyncValue<List<ObservationOnMap>> allObsAsync;

  @override
  Widget build(BuildContext context) {
    return allObsAsync.when(
      loading: () => const SizedBox(height: 160),
      error: (e, _) => Text(
        'Stats indisponibles',
        style: GoogleFonts.karla(color: textMuted),
      ),
      data: (items) {
        final speciesObserved =
            items.map((i) => i.obs.speciesId).toSet().length;
        final totalObs = items.length;
        final withPhoto = items.where((i) => i.obs.photoUrl != null).length;
        final legendary =
            items.where((i) => i.rarity == Rarity.legendary).length;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _StatTile(
              icon: Icons.pets,
              value: '$speciesObserved',
              label: 'Espèces vues',
              color: forestGreen,
            ),
            _StatTile(
              icon: Icons.place_outlined,
              value: '$totalObs',
              label: 'Observations',
              color: terracotta,
            ),
            _StatTile(
              icon: Icons.camera_alt_outlined,
              value: '$withPhoto',
              label: 'Avec photo',
              color: gold,
            ),
            _StatTile(
              icon: Icons.auto_awesome,
              value: '$legendary',
              label: 'Légendaires',
              color: rarityLegendary,
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: color),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: forestGreen,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.karla(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ObserverToggle extends StatelessWidget {
  const _ObserverToggle({
    required this.observersAsync,
    required this.currentObserverId,
    required this.onChanged,
  });

  final AsyncValue<List<AppUser>> observersAsync;
  final String? currentObserverId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return observersAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (e, _) => Text(
        'Observateurs indisponibles',
        style: GoogleFonts.karla(color: textMuted),
      ),
      data: (users) => Row(
        children: [
          for (var i = 0; i < users.length; i++) ...[
            Expanded(
              child: _ObserverButton(
                user: users[i],
                selected: users[i].id == currentObserverId,
                onTap: () => onChanged(users[i].id),
              ),
            ),
            if (i != users.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ObserverButton extends StatelessWidget {
  const _ObserverButton({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AppUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(user.colorAccent.replaceFirst('#', '0xFF')));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? color : surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? surfaceBase.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  user.pseudo.isNotEmpty ? user.pseudo[0] : '?',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: selected ? surfaceBase : color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user.pseudo,
              style: GoogleFonts.karla(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected ? surfaceBase : color,
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'OBSERVATEUR ACTUEL',
                  style: GoogleFonts.karla(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: surfaceBase.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = forestGreen,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/rarity.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/notifications_service.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/data/gamification_state_provider.dart';
import '../../gamification/domain/badge.dart';
import '../../gamification/domain/level.dart';
import '../../observations/data/observations_for_map_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelAsync = ref.watch(accountLevelProvider);
    final allObsAsync = ref.watch(allObservationsForMapProvider);
    final currentAppUser = ref.watch(currentAppUserProvider).asData?.value;
    final currentAuthUser = ref.watch(currentAuthUserProvider);
    final myUserId = currentAuthUser?.id;
    // Stats persos : on filtre les obs partagées sur user_id = soi.
    // Sans ça, Théo et Axelle verraient les mêmes totaux (cf. bug 2026-05-10).
    final myObsAsync = allObsAsync.whenData(
      (items) => myUserId == null
          ? const <ObservationOnMap>[]
          : items.where((i) => i.obs.userId == myUserId).toList(),
    );

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
      // Layout fixe sans scroll : le bloc bas (Réglages) est ancré en bas du
      // viewport via Spacer. La page tient toujours sur un écran standard ;
      // si jamais le contenu dépasse (a11y / petit écran), le Column laissera
      // un overflow visible — préférable au scroll qui éloigne les Réglages.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LevelHeader(
                user: currentAppUser,
                levelAsync: levelAsync,
              ),
              if (currentAuthUser?.email != null) ...[
                const SizedBox(height: 8),
                _AuthEmailLine(email: currentAuthUser!.email!),
              ],
              const SizedBox(height: 16),
              _StatsRow(allObsAsync: myObsAsync),
              const SizedBox(height: 14),
              const _BadgesTeaser(),
              const Spacer(),
              const Divider(color: Color(0xFFE8E0CE)),
              const SizedBox(height: 6),
              const _SectionLabel('Réglages'),
              const SizedBox(height: 4),
              const _StreakNotifsTile(),
              _SettingsTile(
                icon: Icons.logout,
                label: 'Se déconnecter',
                color: const Color(0xFFB8624A),
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      // Sans ça, le dialog s'ouvre sur le root navigator (go_router) et le
      // pop déstacke la route ProfileScreen → black screen + assertion.
      useRootNavigator: false,
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
      // On défère au frame suivant : sinon le redirect auto via
      // _GoRouterRefreshStream se déclenche pendant le pop du dialog →
      // Navigator '_debugLocked' assert + black screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(ref.read(authRepositoryProvider).signOut());
      });
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

/// Rangée compacte de 4 mini-stats — remplace l'ancienne grid 2×2.
/// 1 seule ligne, chiffres + label uppercase, gain de place vertical important.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.allObsAsync});

  final AsyncValue<List<ObservationOnMap>> allObsAsync;

  @override
  Widget build(BuildContext context) {
    return allObsAsync.when(
      loading: () => const SizedBox(height: 72),
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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(
                value: '$speciesObserved',
                label: 'ESPÈCES',
                color: forestGreen,
              ),
              _StatDivider(),
              _MiniStat(
                value: '$totalObs',
                label: 'OBS',
                color: terracotta,
              ),
              _StatDivider(),
              _MiniStat(
                value: '$withPhoto',
                label: 'PHOTOS',
                color: gold,
              ),
              _StatDivider(),
              _MiniStat(
                value: '$legendary',
                label: 'LÉGEND.',
                color: rarityLegendary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.karla(
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE8E0CE),
    );
  }
}

/// Carte "teaser" badges : compteur + 4 derniers débloqués + tap pour ouvrir
/// la grille complète dans un bottom sheet plein écran.
class _BadgesTeaser extends ConsumerWidget {
  const _BadgesTeaser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/badges'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
          ),
          child: badgesAsync.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: forestGreen),
                ),
              ),
            ),
            error: (e, _) => Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: terracotta),
                const SizedBox(width: 10),
                Text(
                  'Badges indisponibles',
                  style: GoogleFonts.karla(color: textMuted),
                ),
              ],
            ),
            data: (statuses) {
              final earned =
                  statuses.where((b) => b.isEarned).toList()
                    ..sort((a, b) => b.earnedAt!.compareTo(a.earnedAt!));
              final preview = earned.take(4).toList();
              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BADGES',
                        style: GoogleFonts.karla(
                          fontSize: 10,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${earned.length} / ${statuses.length}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: forestGreen,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: preview.isEmpty
                        ? Text(
                            'Pas encore débloqué',
                            style: GoogleFonts.karla(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: textMuted,
                            ),
                          )
                        : Row(
                            children: [
                              for (final s in preview) ...[
                                _BadgePreviewBubble(badge: s),
                                const SizedBox(width: 6),
                              ],
                            ],
                          ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 22, color: forestGreen),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

}

class _BadgePreviewBubble extends StatelessWidget {
  const _BadgePreviewBubble({required this.badge});

  final BadgeStatus badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: gold.withValues(alpha: 0.6), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(badge.def.icon, style: const TextStyle(fontSize: 18)),
    );
  }
}

class _AuthEmailLine extends StatelessWidget {
  const _AuthEmailLine({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.alternate_email, size: 14, color: textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            email,
            style: GoogleFonts.karla(
              fontSize: 12,
              color: textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Switch "Rappel quotidien série" : enable/disable la notif locale à 13:00.
class _StreakNotifsTile extends ConsumerWidget {
  const _StreakNotifsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(notificationsEnabledProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              size: 20, color: forestGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rappel quotidien',
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: forestGreen,
                  ),
                ),
                Text(
                  'Notification à 13:00 pour entretenir ta série',
                  style: GoogleFonts.karla(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          enabledAsync.when(
            loading: () => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: forestGreen),
            ),
            error: (e, _) => const Icon(Icons.error, color: terracotta),
            data: (enabled) => Switch.adaptive(
              value: enabled,
              activeThumbColor: surfaceBase,
              activeTrackColor: forestGreen,
              onChanged: (v) async {
                final service = ref.read(notificationsServiceProvider);
                if (v) {
                  final ok = await service.enable();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: terracotta,
                        content: Text(
                          "Permission refusée — autorise les notifs dans les réglages système.",
                          style: GoogleFonts.karla(color: surfaceBase),
                        ),
                      ),
                    );
                  }
                } else {
                  await service.disable();
                }
                ref.invalidate(notificationsEnabledProvider);
              },
            ),
          ),
        ],
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

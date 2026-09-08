import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/gamification_state_provider.dart';
import '../domain/badge.dart';

/// Wrap d'écran qui consomme la file [pendingBadgeCelebrationsProvider] et
/// déclenche un dialog "badge déverrouillé" pour chaque badge nouvellement
/// unlock. Plus de confetti — l'identité visuelle vient maintenant du halo
/// coloré + scale-in elasticOut + shimmer (gradué par catégorie).
class BadgeUnlockOverlay extends ConsumerStatefulWidget {
  const BadgeUnlockOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BadgeUnlockOverlay> createState() => _BadgeUnlockOverlayState();
}

class _BadgeUnlockOverlayState extends ConsumerState<BadgeUnlockOverlay> {
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    // ref.listen ne fire pas sur la valeur initiale. Si l'overlay se mount
    // alors que la file est déjà non vide (cas typique : badge unlock pendant
    // qu'on était sur new_observation_screen), on déclenche manuellement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeCelebrateNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch always-alive de badgesProvider — sinon il ne tourne QUE quand
    // l'user est sur la page badges / le teaser du profil, et l'auto-unlock
    // (INSERT + push dans la file de célébration) ne se déclenche jamais
    // depuis la Home après une nouvelle obs. Bug remonté 2026-09.
    // Le résultat n'est pas utilisé ici — c'est purement pour keep alive.
    ref.watch(badgesProvider);

    // À chaque évolution de la file, on tente de célébrer le prochain.
    ref.listen<List<String>>(pendingBadgeCelebrationsProvider, (_, _) {
      _maybeCelebrateNext();
    });
    return widget.child;
  }

  /// Pop la 1ʳᵉ entrée de la file et lance la célébration. No-op si la file
  /// est vide ou si une célébration est déjà en cours.
  void _maybeCelebrateNext() {
    if (_showingDialog) return;
    final pending = ref.read(pendingBadgeCelebrationsProvider);
    if (pending.isEmpty) return;
    final nextId = pending.first;
    // Résout le BadgeDef depuis allBadges (la définition est en code, pas BDD).
    final def = allBadges.cast<BadgeDef?>().firstWhere(
          (d) => d!.id == nextId,
          orElse: () => null,
        );
    if (def == null) {
      // ID inconnu (badge supprimé du catalogue) → on nettoie la file.
      _popPending(nextId);
      return;
    }
    _showCelebration(def);
  }

  void _popPending(String id) {
    final notifier = ref.read(pendingBadgeCelebrationsProvider.notifier);
    notifier.state = notifier.state.where((x) => x != id).toList();
  }

  Future<void> _showCelebration(BadgeDef badge) async {
    _showingDialog = true;
    unawaited(HapticFeedback.mediumImpact());
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _BadgeUnlockDialog(badge: badge),
    );
    _showingDialog = false;
    // Retire le badge célébré de la file. Le listener va re-fire et
    // _maybeCelebrateNext s'occupera du suivant si la file n'est pas vide.
    if (!mounted) return;
    _popPending(badge.id);
  }
}

/// Dialog de déblocage de badge. Couleur de halo + intensité selon la
/// catégorie pour différencier visuellement les types de badges :
///   - firstSteps (jalons espèces)  : halo doré, scale-in classique
///   - rarity (1ʳᵉ épique/légendaire) : halo selon couleur rareté + shimmer
///                                      sur le nom
///   - photo                         : halo doré + petite étincelle "flash"
///   - streak                        : halo terracotta + icône pulsante
///                                      (la flamme respire)
class _BadgeUnlockDialog extends StatefulWidget {
  const _BadgeUnlockDialog({required this.badge});

  final BadgeDef badge;

  @override
  State<_BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<_BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _halo;

  @override
  void initState() {
    super.initState();
    // Halo pulsant pour donner de la vie à l'icône (toutes catégories).
    _halo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  /// Couleur de halo selon la catégorie du badge.
  Color get _haloColor => switch (widget.badge.category) {
        BadgeCategory.firstSteps => gold,
        BadgeCategory.rarity => terracotta,
        BadgeCategory.photo => forestGreen,
        BadgeCategory.streak => terracotta,
        BadgeCategory.collection => forestGreen,
        BadgeCategory.mystery => gold,
      };

  /// Le nom du badge a un shimmer permanent pour la catégorie rarity (rare
  /// = effet "trophée brillant"). Sinon nom statique.
  bool get _nameShimmer => widget.badge.category == BadgeCategory.rarity;

  /// Pour les badges de série (🔥), on fait pulser l'emoji en scale continu
  /// pour évoquer la "flamme qui respire".
  bool get _iconPulse => widget.badge.category == BadgeCategory.streak;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'BADGE DÉBLOQUÉ',
            style: GoogleFonts.karla(
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.bold,
              color: terracotta,
            ),
          ),
          const SizedBox(height: 14),
          _BadgeHero(
            emoji: widget.badge.icon,
            haloColor: _haloColor,
            halo: _halo,
            pulse: _iconPulse,
          ),
          const SizedBox(height: 12),
          _buildName(),
          const SizedBox(height: 6),
          Text(
            widget.badge.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.karla(
              fontSize: 13,
              color: textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(backgroundColor: forestGreen),
            child: Text(
              'Bravo !',
              style: GoogleFonts.karla(
                fontWeight: FontWeight.bold,
                color: surfaceBase,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildName() {
    final text = Text(
      widget.badge.name,
      textAlign: TextAlign.center,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: forestGreen,
      ),
    );
    if (!_nameShimmer) return text;
    return text.animate(onPlay: (c) => c.repeat()).shimmer(
          duration: const Duration(milliseconds: 1800),
          color: _haloColor.withValues(alpha: 0.7),
        );
  }
}

/// Cercle gradient halo + emoji centré. Scale-in elasticOut au mount.
/// Halo pulse en continu via [halo] (controller passé par le parent).
/// Si [pulse] est true, l'emoji lui-même pulse en scale (1.0 → 1.08 → 1.0).
class _BadgeHero extends StatelessWidget {
  const _BadgeHero({
    required this.emoji,
    required this.haloColor,
    required this.halo,
    required this.pulse,
  });

  final String emoji;
  final Color haloColor;
  final Animation<double> halo;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    Widget icon = AnimatedBuilder(
      animation: halo,
      builder: (_, _) {
        final haloAlpha = 0.25 + 0.35 * halo.value;
        final haloBlur = 16.0 + halo.value * 14.0;
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: surfaceCard,
            border: Border.all(color: haloColor.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: haloColor.withValues(alpha: haloAlpha),
                blurRadius: haloBlur,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 56)),
        );
      },
    );
    if (pulse) {
      // Pulse continu de l'emoji pour la catégorie streak (flamme vivante).
      icon = icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.06, 1.06),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
          );
    }
    // Scale-in d'entrée avec elasticOut (bounce léger).
    return icon.animate().scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
        );
  }
}

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/gamification_state_provider.dart';
import '../domain/badge.dart';

/// Wrap d'écran qui consomme la file [pendingBadgeCelebrationsProvider] et
/// déclenche une animation "badge déverrouillé" (confetti + dialog) pour
/// chaque badge nouvellement unlock.
///
/// Architecture : badgesProvider est responsable de l'INSERT en BDD et de
/// pousser le badge_id dans la file. L'overlay pop la 1ʳᵉ entrée, célèbre,
/// puis retire de la file. Si plusieurs badges sont en attente, ils
/// s'enchaînent automatiquement.
class BadgeUnlockOverlay extends ConsumerStatefulWidget {
  const BadgeUnlockOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BadgeUnlockOverlay> createState() => _BadgeUnlockOverlayState();
}

class _BadgeUnlockOverlayState extends ConsumerState<BadgeUnlockOverlay> {
  bool _showingDialog = false;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    // ref.listen ne fire pas sur la valeur initiale. Si l'overlay se mount
    // alors que la file est déjà non vide (cas typique : badge unlock pendant
    // qu'on était sur new_observation_screen), on déclenche manuellement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeCelebrateNext();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // À chaque évolution de la file, on tente de célébrer le prochain.
    ref.listen<List<String>>(pendingBadgeCelebrationsProvider, (_, _) {
      _maybeCelebrateNext();
    });

    return Stack(
      children: [
        widget.child,
        // Confetti centré en haut, fire vers le bas.
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: math.pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            maxBlastForce: 22,
            minBlastForce: 8,
            emissionFrequency: 0.06,
            numberOfParticles: 18,
            gravity: 0.25,
            colors: const [
              gold,
              goldLight,
              forestGreen,
              terracotta,
              Color(0xFFFCE7C8),
            ],
          ),
        ),
      ],
    );
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
    _confetti.play();
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
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
            Text(badge.icon, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 10),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: forestGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.description,
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
      ),
    );
    _showingDialog = false;
    // Retire le badge célébré de la file. Le listener va re-fire et
    // _maybeCelebrateNext s'occupera du suivant si la file n'est pas vide.
    if (!mounted) return;
    _popPending(badge.id);
  }
}

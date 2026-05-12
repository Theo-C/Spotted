import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/gamification_state_provider.dart';
import '../domain/badge.dart';

/// Écoute le badgesProvider, détecte les unlocks et déclenche une animation
/// "badge déverrouillé" (confetti + dialog). À monter sur la Home : c'est
/// l'écran où l'user revient après une obs, donc le bon moment pour fêter.
class BadgeUnlockOverlay extends ConsumerStatefulWidget {
  const BadgeUnlockOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BadgeUnlockOverlay> createState() => _BadgeUnlockOverlayState();
}

class _BadgeUnlockOverlayState extends ConsumerState<BadgeUnlockOverlay> {
  /// IDs des badges déjà connus comme earned (snapshot du précédent build).
  /// On en garde une copie pour faire un diff au prochain rebuild.
  Set<String>? _previouslyEarned;
  bool _showingDialog = false;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écoute des changements de la liste de badges earned : à chaque nouveau
    // earned, on déclenche la célébration.
    ref.listen<AsyncValue<List<BadgeStatus>>>(badgesProvider, (prev, next) {
      final statuses = next.asData?.value;
      if (statuses == null) return;
      final earnedNow = statuses
          .where((b) => b.isEarned)
          .map((b) => b.def.id)
          .toSet();

      if (_previouslyEarned == null) {
        // 1er chargement : on initialise sans déclencher d'anim.
        _previouslyEarned = earnedNow;
        return;
      }

      final newlyEarned =
          earnedNow.difference(_previouslyEarned!).toList();
      _previouslyEarned = earnedNow;
      if (newlyEarned.isEmpty || _showingDialog) return;

      // Affiche la 1ʳᵉ nouvelle unlock (si plusieurs : seules les autres
      // s'afficheront sur les écrans suivants — bonne UX, pas de cascade).
      final unlocked = statuses.firstWhere(
        (s) => s.def.id == newlyEarned.first,
      );
      _showCelebration(unlocked.def);
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
  }
}

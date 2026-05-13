import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/gamification_providers.dart';
import '../domain/level.dart';

/// Wrap d'écran qui écoute [accountLevelProvider] et déclenche une animation
/// "Level Up !" quand le niveau augmente. À monter sur la Home (à côté du
/// BadgeUnlockOverlay) — l'user revient sur la Home après une obs, c'est le
/// bon endroit pour célébrer le passage.
///
/// L'animation est volontairement plus sobre que la dialog badge :
///   - pas de modal bloquant (l'user n'a rien à valider)
///   - overlay qui apparaît du haut, reste 2s, fade out
///   - haptic heavyImpact au reveal
///   - shimmer sur le numéro de niveau
class LevelUpOverlay extends ConsumerStatefulWidget {
  const LevelUpOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends ConsumerState<LevelUpOverlay> {
  /// Dernier niveau vu — sert à détecter les transitions N → N+1.
  /// Null au mount → on ne déclenche pas l'anim au 1er chargement (sinon
  /// chaque retour sur la home re-célébrerait).
  int? _lastSeenLevel;
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LevelInfo>>(accountLevelProvider, (prev, next) {
      final info = next.asData?.value;
      if (info == null) return;
      final seen = _lastSeenLevel;
      _lastSeenLevel = info.value;
      // 1er chargement : on initialise sans rien déclencher.
      if (seen == null) return;
      // Transition N → N+k (k > 0 — un gain massif peut sauter 2 niveaux).
      if (info.value > seen && !_showing) {
        _showLevelUp(info.value);
      }
    });

    return widget.child;
  }

  Future<void> _showLevelUp(int newLevel) async {
    _showing = true;
    unawaited(HapticFeedback.heavyImpact());
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: _LevelUpBanner(level: newLevel),
      ),
    );
    Overlay.of(context).insert(entry);
    // Banner dure ~2s (fade in 200 + tenue 1500 + fade out 400 dans
    // flutter_animate). On l'enlève après 2.5s pour être safe.
    await Future.delayed(const Duration(milliseconds: 2500));
    entry.remove();
    _showing = false;
  }
}

/// Bannière "Niveau X atteint" qui slide-in du haut + shimmer sur le numéro.
class _LevelUpBanner extends StatelessWidget {
  const _LevelUpBanner({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [forestGreen, forestGreenLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: forestGreen.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pastille niveau avec shimmer
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [goldLight, gold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: goldLight.withValues(alpha: 0.6),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$level',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(
                      duration: const Duration(milliseconds: 1400),
                      color: surfaceBase.withValues(alpha: 0.6),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NIVEAU SUPÉRIEUR',
                    style: GoogleFonts.karla(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC4A572),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Niveau $level atteint',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: surfaceBase,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .slideY(
          begin: -1.2,
          end: 0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: const Duration(milliseconds: 200))
        .then(delay: const Duration(milliseconds: 1500))
        .fadeOut(duration: const Duration(milliseconds: 400))
        .slideY(end: -0.5, duration: const Duration(milliseconds: 400));
  }
}

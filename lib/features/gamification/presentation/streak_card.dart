import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/gamification_state_provider.dart';

/// Carte de série affichée en haut de la Home.
/// Trois états visuels selon la série :
///   - Active aujourd'hui (obs faite dans la journée) → flamme vermillon, fond chaud
///   - En grâce (a observé hier mais pas aujourd'hui) → flamme orange terne + warning
///   - Inactive (série 0 ou rompue) → flamme grise, encouragement à démarrer
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final isActive = streak.isActiveToday;
    final isGrace = streak.isInGrace;
    final isOff = streak.current == 0;

    // Palette selon l'état
    final flameColor = isOff
        ? textMuted
        : isGrace
            ? const Color(0xFFE08E2C) // orange terne urgence
            : terracotta;
    final bgGradient = isOff
        ? const [Color(0xFFEEE7D5), Color(0xFFE2DAC4)]
        : isGrace
            ? const [Color(0xFFFCE7C8), Color(0xFFF6D4A2)]
            : const [Color(0xFFFDE5C9), Color(0xFFFAB78A)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgGradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: flameColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Flamme + compteur
            _FlameIcon(color: flameColor, animated: isActive),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${streak.current}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: forestGreen,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        streak.current <= 1 ? 'jour' : 'jours',
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLine(streak.isActiveToday, streak.isInGrace,
                        streak.current),
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Multiplicateur XP courant (s'affiche dès qu'il y en a un)
            if (streak.xpMultiplier > 1.0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: forestGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '×${streak.xpMultiplier.toStringAsFixed(2)}',
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: goldLight,
                  ),
                ),
              )
            else if (streak.nextThreshold != null && streak.current > 0)
              // Pas encore au palier J7 mais en route → affichage du goal
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: surfaceBase.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: flameColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'J${streak.nextThreshold}',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: forestGreen,
                      ),
                    ),
                    Text(
                      'dans ${streak.daysToNextThreshold}j',
                      style: GoogleFonts.karla(
                        fontSize: 9,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLine(bool active, bool grace, int current) {
    if (current == 0) {
      return 'Démarre ta série : 1 obs par jour suffit.';
    }
    if (active) {
      final next = current >= 100
          ? 'Bonus +50% au maximum 🔥'
          : current >= 30
              ? 'Bonus +25% actif'
              : current >= 7
                  ? 'Bonus +10% actif'
                  : 'Continue, +10% à J7 !';
      return 'Obs validée aujourd\'hui · $next';
    }
    if (grace) {
      return 'Plus que ce soir pour conserver ta série !';
    }
    return 'Série en cours';
  }
}

/// Icône flamme animée (pulse léger quand active aujourd'hui).
class _FlameIcon extends StatefulWidget {
  const _FlameIcon({required this.color, required this.animated});

  final Color color;
  final bool animated;

  @override
  State<_FlameIcon> createState() => _FlameIconState();
}

class _FlameIconState extends State<_FlameIcon>
    with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(covariant _FlameIcon old) {
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
        final scale = 1.0 + (_ctrl.value * 0.10);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: surfaceBase.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              boxShadow: widget.animated
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 16 + _ctrl.value * 8,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: const Text('🔥', style: TextStyle(fontSize: 26)),
          ),
        );
      },
    );
  }
}

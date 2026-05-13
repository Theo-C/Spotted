import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/gamification_state_provider.dart';
import '../domain/quest.dart';

/// Section "Quêtes du jour" affichée sur la Home.
/// Liste les 3 quêtes journalières avec leur progression + bouton "Réclamer"
/// quand complète mais pas encore réclamée.
class DailyQuestsSection extends ConsumerWidget {
  const DailyQuestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(dailyQuestsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: textMuted.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'QUÊTES DU JOUR',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
                const Spacer(),
                questsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (quests) {
                    final done = quests.where((q) => q.claimed).length;
                    return Text(
                      '$done / ${quests.length}',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: forestGreen,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            questsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: forestGreen,
                    ),
                  ),
                ),
              ),
              error: (e, _) => Text(
                'Quêtes indisponibles',
                style: GoogleFonts.karla(color: textMuted, fontSize: 12),
              ),
              data: (quests) => Column(
                children: [
                  for (var i = 0; i < quests.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _QuestRow(status: quests[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestRow extends ConsumerStatefulWidget {
  const _QuestRow({required this.status});

  final QuestStatus status;

  @override
  ConsumerState<_QuestRow> createState() => _QuestRowState();
}

class _QuestRowState extends ConsumerState<_QuestRow>
    with SingleTickerProviderStateMixin {
  bool _claiming = false;

  /// Controller pour le pulse du bouton "Réclamer" au tap.
  /// forward (1.0 → 0.92) → reverse (0.92 → 1.0), 200ms total.
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  /// Clé sur le bouton pour récupérer sa position globale et y attacher
  /// le flottant "+XP" via l'Overlay.
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pulse = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final pct = s.progress.value.clamp(0.0, 1.0);
    final claimable = s.isClaimable;
    final claimed = s.claimed;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icône emoji
        SizedBox(
          width: 28,
          child: Text(
            s.def.icon,
            style: const TextStyle(fontSize: 22),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 10),
        // Texte + barre de progression
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.def.name,
                      style: GoogleFonts.karla(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: claimed ? textMuted : textPrimary,
                        decoration: claimed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                  Text(
                    '+${s.def.xpReward} XP',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: claimed ? textMuted : gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    claimed
                        ? textMuted
                        : claimable
                            ? forestGreen
                            : terracotta,
                  ),
                ),
              ),
              if (s.progress.label != null) ...[
                const SizedBox(height: 2),
                Text(
                  s.progress.label!,
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Bouton claim / coche
        _trailing(claimable: claimable, claimed: claimed),
      ],
    );
  }

  Widget _trailing({required bool claimable, required bool claimed}) {
    if (claimed) {
      // Check qui apparaît avec scale-in + petit bounce quand le quest passe
      // de claimable → claimed. flutter_animate déclenche sur build.
      return const Icon(Icons.check_circle, size: 22, color: forestGreen)
          .animate()
          .scale(
            begin: const Offset(0.4, 0.4),
            end: const Offset(1, 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: const Duration(milliseconds: 120));
    }
    if (!claimable) {
      return const SizedBox(width: 22);
    }
    return ScaleTransition(
      scale: _pulse,
      child: SizedBox(
        key: _buttonKey,
        height: 28,
        child: ElevatedButton(
          onPressed: _claiming ? null : _onClaim,
          style: ElevatedButton.styleFrom(
            backgroundColor: forestGreen,
            foregroundColor: surfaceBase,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _claiming
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: surfaceBase,
                  ),
                )
              : Text(
                  'RÉCLAMER',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  /// Insère un flottant "+XP" au-dessus du bouton, qui monte de ~36 px en
  /// fadant. Le calcul de position se fait via la GlobalKey sur le bouton.
  void _showFloatingXp(int xp) {
    final overlayState = Overlay.maybeOf(context);
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayState == null || box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: pos.dx - 20,
        top: pos.dy - 24,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Text(
              '+$xp XP',
              style: GoogleFonts.karla(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: gold,
                shadows: const [
                  Shadow(color: Color(0x55000000), blurRadius: 6),
                ],
              ),
            ).animate()
                .moveY(
                  begin: 0,
                  end: -36,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(duration: const Duration(milliseconds: 120))
                .then(delay: const Duration(milliseconds: 500))
                .fadeOut(duration: const Duration(milliseconds: 300)),
          ),
        ),
      ),
    );
    overlayState.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _onClaim() async {
    // Pulse + haptic dès le tap, avant l'aller-retour BDD pour un retour
    // immédiat (vs attendre la réponse réseau pour réagir).
    unawaited(HapticFeedback.lightImpact());
    _pulseController.forward().then((_) => _pulseController.reverse());
    setState(() => _claiming = true);

    final xp = widget.status.def.xpReward;
    _showFloatingXp(xp);

    try {
      final claimer = ref.read(questClaimerProvider);
      await claimer(widget.status.def);
      // Pas de snackbar : le flottant +XP + le check qui apparaît dans la
      // row sont le feedback. Plus discret, plus rapide à enchaîner.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur : $e',
            style: GoogleFonts.karla(color: surfaceBase),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }
}

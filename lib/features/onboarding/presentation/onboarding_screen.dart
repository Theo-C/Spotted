import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/services/notifications_service.dart';
import '../../../core/services/onboarding_service.dart';

/// Onboarding 3-step montré au 1er login (ou si l'utilisateur n'a jamais
/// terminé la config). Migre le tip GPS caméra et la dialog opt-in notifs
/// hors de la Home, qui peut rester épurée.
///
/// Étapes :
///   1. Bienvenue
///   2. Active "Enregistrer la localisation" dans l'app caméra (= tip GPS)
///   3. Active les rappels quotidiens (optionnel, déclenche la demande de
///      permission notif OS)
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;
  bool _notifBusy = false;

  static const _stepCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < _stepCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingServiceProvider).markComplete();
    // Le router refresh va rediriger vers / automatiquement. Mais on push
    // explicitement au cas où le router prend une frame à se synchroniser.
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _enableNotifs() async {
    setState(() => _notifBusy = true);
    final service = ref.read(notificationsServiceProvider);
    final ok = await service.enable();
    await service.markOptInPromptShown();
    if (!mounted) return;
    setState(() => _notifBusy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: terracotta,
          content: Text(
            "Permission refusée — tu pourras activer plus tard dans Profil.",
            style: GoogleFonts.karla(color: surfaceBase),
          ),
        ),
      );
    }
    await _finish();
  }

  Future<void> _skipNotifs() async {
    // On marque quand même le prompt comme vu pour ne pas re-déclencher la
    // dialog d'opt-in plus tard depuis ailleurs.
    await ref.read(notificationsServiceProvider).markOptInPromptShown();
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              // Header : skip + indicateur d'étape
              Row(
                children: [
                  _StepDots(active: _index, total: _stepCount),
                  const Spacer(),
                  if (_index < _stepCount - 1)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Passer',
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  children: const [
                    _WelcomeStep(),
                    _CameraGpsStep(),
                    _NotifStep(),
                  ],
                ),
              ),
              // Bouton primaire — varie selon l'étape
              if (_index == _stepCount - 1) ...[
                FilledButton(
                  onPressed: _notifBusy ? null : _enableNotifs,
                  style: FilledButton.styleFrom(
                    backgroundColor: forestGreen,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _notifBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: surfaceBase,
                          ),
                        )
                      : Text(
                          'Activer les rappels',
                          style: GoogleFonts.karla(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: surfaceBase,
                          ),
                        ),
                ),
                TextButton(
                  onPressed: _notifBusy ? null : _skipNotifs,
                  child: Text(
                    'Plus tard',
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ),
              ] else
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: forestGreen,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Suivant',
                    style: GoogleFonts.karla(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: surfaceBase,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? forestGreen : const Color(0xFFE8E0CE),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.visual,
    required this.title,
    required this.body,
  });

  /// Visuel d'entête : Image.asset pour le welcome (logo Spotted), emoji
  /// pour les autres étapes.
  final Widget visual;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          visual,
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: forestGreen,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          DefaultTextStyle(
            style: GoogleFonts.karla(
              fontSize: 13,
              color: textPrimary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            child: body,
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      visual: Image.asset(
        'assets/icon/icon.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
      title: 'Bienvenue dans Spotted',
      body: const Text(
        "Ton carnet naturaliste perso. Pour chaque territoire, "
        "tu consultes les espèces remarquables, tu les observes sur "
        "le terrain, et tu valides tes découvertes avec une photo.",
      ),
    );
  }
}

class _CameraGpsStep extends StatelessWidget {
  const _CameraGpsStep();

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      visual: const Text('📷', style: TextStyle(fontSize: 84)),
      title: 'Configure ton app caméra',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Active « Enregistrer la localisation » dans Open Camera, "
            "Google Camera, ou ton app caméra habituelle.",
            textAlign: TextAlign.center,
            style: GoogleFonts.karla(
              fontSize: 13,
              color: textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 18, color: gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Sans ça, Android retire les coordonnées GPS des photos à "
                    "l'import — il faudra placer le point manuellement.",
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      color: textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifStep extends StatelessWidget {
  const _NotifStep();

  @override
  Widget build(BuildContext context) {
    return const _StepLayout(
      visual: Text('🔔', style: TextStyle(fontSize: 84)),
      title: 'Rappel quotidien',
      body: Text(
        "Un petit rappel à 13:00 chaque jour pour ne pas casser ta série "
        "naturaliste. Tu peux refuser et l'activer plus tard dans Profil.",
      ),
    );
  }
}

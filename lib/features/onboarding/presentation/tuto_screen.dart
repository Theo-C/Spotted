import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Tuto de 5 pages qui explique comment fonctionne Spotted.
///
/// Distinct de l'[OnboardingScreen] qui gère les permissions (localisation
/// dans la photo + notifs). Le tuto est indépendant :
///   - joué automatiquement après l'onboarding pour les nouveaux users
///   - re-consultable à tout moment via Profil → menu → "Comment ça marche"
///
/// Animations : chaque page fait un fadeIn + slideY en cascade sur ses
/// éléments (via flutter_animate), et l'emoji hero fait un scale-in
/// elasticOut. Le but est de rendre le tuto vivant sans surcharger.
class TutoScreen extends ConsumerStatefulWidget {
  const TutoScreen({super.key});

  @override
  ConsumerState<TutoScreen> createState() => _TutoScreenState();
}

class _TutoScreenState extends ConsumerState<TutoScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _stepCount = 5;

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
      _finish();
    }
  }

  Future<void> _prev() async {
    if (_index == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _finish() {
    // pop plutôt que context.go('/') — le caller (onboarding ou profil) gère
    // la destination. Si le tuto est ouvert en top-level (deep link direct
    // ou en fin d'onboarding via context.go), pop n'a pas de cible : on
    // retombe sur Home via canPop check.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _stepCount - 1;
    return Scaffold(
      backgroundColor: surfaceBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _StepDots(active: _index, total: _stepCount),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      isLast ? 'Fermer' : 'Passer',
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
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    // ValueKey(_index) sur chaque page pour que flutter_animate
                    // re-joue les animations à chaque swipe (sans la clé, la
                    // page n'est instanciée qu'une fois et l'anim est passée).
                    _PokedexStep(key: ValueKey('p0-$_index')),
                    _ExplorerStep(key: ValueKey('p1-$_index')),
                    _ObserveStep(key: ValueKey('p2-$_index')),
                    _RarityBadgesStep(key: ValueKey('p3-$_index')),
                    _CarnetStep(key: ValueKey('p4-$_index')),
                  ],
                ),
              ),
              Row(
                children: [
                  if (_index > 0)
                    OutlinedButton(
                      onPressed: _prev,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: forestGreen, width: 1.5),
                        minimumSize: const Size(80, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.chevron_left,
                          color: forestGreen),
                    ),
                  if (_index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: forestGreen,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isLast ? "C'est parti !" : 'Suivant',
                        style: GoogleFonts.karla(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: surfaceBase,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// Layout partagé — emoji hero + titre + body avec cascade animée
// =============================================================

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.emoji,
    required this.title,
    required this.tagline,
    required this.children,
  });

  final String emoji;
  final String title;
  final String tagline;

  /// Blocs additionnels sous le tagline (mini-illustrations, key points…).
  /// Chaque enfant reçoit une anim fadeIn + slideY décalée dans le temps.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Emoji hero — scale-in elasticOut pour un côté "pop up".
          Text(emoji, style: const TextStyle(fontSize: 84))
              .animate()
              .scale(
                begin: const Offset(0.3, 0.3),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: forestGreen,
              height: 1.15,
            ),
          )
              .animate()
              .fadeIn(
                delay: const Duration(milliseconds: 150),
                duration: const Duration(milliseconds: 400),
              )
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 12),
          Text(
            tagline,
            textAlign: TextAlign.center,
            style: GoogleFonts.karla(
              fontSize: 14,
              color: textPrimary,
              height: 1.55,
            ),
          )
              .animate()
              .fadeIn(
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 400),
              )
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 20),
          // Cascade sur les enfants additionnels — chaque bloc apparaît 100ms
          // après le précédent pour un effet "les infos qui se posent".
          for (var i = 0; i < children.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: children[i]
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 450 + i * 100),
                    duration: const Duration(milliseconds: 400),
                  )
                  .slideY(begin: 0.3, end: 0),
            ),
          ],
        ],
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

/// Encart "point clé" — barre gauche colorée + icône + texte. Utilisé pour
/// mettre en avant les infos secondaires sur chaque page du tuto.
class _KeyPoint extends StatelessWidget {
  const _KeyPoint({
    required this.icon,
    required this.text,
    this.color = forestGreen,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: GoogleFonts.karla(
                fontSize: 13,
                color: textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Pages — 5 étapes du tuto
// =============================================================

class _PokedexStep extends StatelessWidget {
  const _PokedexStep({super.key});

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      emoji: '📔',
      title: 'Un carnet des espèces',
      tagline: 'Chaque département a sa sélection d\'espèces à débusquer. '
          'Tu les observes sur le terrain, tu valides avec une photo.',
      children: const [
        _RarityRow(),
        _KeyPoint(
          icon: Icons.pets,
          text: 'Faune uniquement : oiseaux, mammifères, reptiles, '
              'chauves-souris.',
        ),
      ],
    );
  }
}

/// Rangée des 4 raretés — sert d'exemple visuel concret dans la page 1 pour
/// vulgariser "plus c'est rare, plus ça rapporte".
class _RarityRow extends StatelessWidget {
  const _RarityRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'CHAQUE ESPÈCE A UNE RARETÉ',
          style: GoogleFonts.karla(
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _RarityChip(label: 'Commun', color: rarityCommon),
            _RarityChip(label: 'Rare', color: rarityRare),
            _RarityChip(label: 'Épique', color: rarityEpic),
            _RarityChip(label: 'Légend.', color: rarityLegendary),
          ],
        ),
      ],
    );
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.karla(
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _ExplorerStep extends StatelessWidget {
  const _ExplorerStep({super.key});

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      emoji: '🗺️',
      title: 'Explorer un territoire',
      tagline: 'Depuis l\'accueil, tu choisis un département puis une '
          'catégorie. Tu tombes sur la liste des espèces à trouver là-bas.',
      children: const [
        _NavPath(),
        _KeyPoint(
          icon: Icons.filter_alt_outlined,
          text: 'Filtre par rareté ou par "non vues" pour cibler ta prochaine '
              'sortie.',
        ),
        _KeyPoint(
          icon: Icons.visibility_off_outlined,
          text: 'Les espèces jamais observées restent floutées — la surprise '
              'fait partie du jeu.',
        ),
      ],
    );
  }
}

/// Mini-fil d'Ariane visuel montrant le chemin de navigation typique.
class _NavPath extends StatelessWidget {
  const _NavPath();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _NavStep(emoji: '🏠', label: 'Accueil'),
          _NavArrow(),
          _NavStep(emoji: '📍', label: 'Oise'),
          _NavArrow(),
          _NavStep(emoji: '🐦', label: 'Oiseaux'),
        ],
      ),
    );
  }
}

class _NavStep extends StatelessWidget {
  const _NavStep({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.karla(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.arrow_forward, size: 14, color: terracotta),
    );
  }
}

class _ObserveStep extends StatelessWidget {
  const _ObserveStep({super.key});

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      emoji: '📸',
      title: 'Valider une observation',
      tagline: 'Bouton + sur l\'accueil, tu choisis une photo. L\'app détecte '
          'où tu étais et te propose l\'espèce.',
      children: const [
        _ObsTimeline(),
        _KeyPoint(
          icon: Icons.location_off_outlined,
          text: 'Pas de localisation dans la photo ? Place le point sur la '
              'carte ou tape le nom d\'une ville.',
        ),
        _KeyPoint(
          icon: Icons.auto_awesome,
          text: 'La reconnaissance visuelle te suggère l\'espèce, tu confirmes '
              '(ou tu choisis manuellement).',
          color: terracotta,
        ),
      ],
    );
  }
}

/// Timeline 3 étapes de la saisie d'une obs — donne l'impression que c'est
/// rapide et automatique, ce qui est le principal argument.
class _ObsTimeline extends StatelessWidget {
  const _ObsTimeline();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _ObsStep(n: 1, icon: Icons.photo_library_outlined,
            label: 'Photo')),
        _TimelineDash(),
        Expanded(child: _ObsStep(n: 2, icon: Icons.pin_drop_outlined,
            label: 'Détection')),
        _TimelineDash(),
        Expanded(child: _ObsStep(n: 3, icon: Icons.check_circle_outline,
            label: 'Validation')),
      ],
    );
  }
}

class _ObsStep extends StatelessWidget {
  const _ObsStep({required this.n, required this.icon, required this.label});

  final int n;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: forestGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: forestGreen, width: 1.5),
          ),
          child: Center(
            child: Icon(icon, size: 18, color: forestGreen),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$n. $label',
          style: GoogleFonts.karla(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TimelineDash extends StatelessWidget {
  const _TimelineDash();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 1.5,
      color: const Color(0xFFE8E0CE),
      margin: const EdgeInsets.only(bottom: 20),
    );
  }
}

class _RarityBadgesStep extends StatelessWidget {
  const _RarityBadgesStep({super.key});

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      emoji: '⭐',
      title: 'Points, séries et badges',
      tagline: 'Chaque observation rapporte des points selon la rareté. '
          'Ajouter une photo donne un bonus.',
      children: const [
        _ExampleObs(),
        _KeyPoint(
          icon: Icons.workspace_premium_outlined,
          text: 'Des badges à collectionner : par famille (mésanges, pics…), '
              'et des mystères cachés à découvrir.',
          color: gold,
        ),
        _KeyPoint(
          icon: Icons.local_fire_department_outlined,
          text: 'Une observation par jour = une série. Un rappel à 13h peut '
              't\'aider à ne pas la casser.',
          color: terracotta,
        ),
      ],
    );
  }
}

/// Exemple concret "voici ce que rapporte une obs" — rend la mécanique
/// points × rareté × photo palpable au lieu de rester abstrait.
class _ExampleObs extends StatelessWidget {
  const _ExampleObs();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🦅', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faucon pèlerin',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: forestGreen,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const _RarityChip(label: 'Épique', color: rarityEpic),
                    const SizedBox(width: 6),
                    Text(
                      '+100 pts',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(150 avec photo)',
                      style: GoogleFonts.karla(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarnetStep extends StatelessWidget {
  const _CarnetStep({super.key});

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      emoji: '📍',
      title: 'Ton carnet géo',
      tagline: 'L\'onglet Carnet affiche toutes tes observations sur une '
          'carte. Chaque point est coloré selon la rareté de l\'espèce.',
      children: const [
        _MiniMapMock(),
        _KeyPoint(
          icon: Icons.tune,
          text: 'Filtres par catégorie ou rareté pour retrouver rapidement '
              'une observation.',
        ),
        _KeyPoint(
          icon: Icons.layers_outlined,
          text: '3 styles de carte disponibles : relief, satellite, standard.',
        ),
      ],
    );
  }
}

/// Mock visuel d'un extrait de carnet géo — 4 pastilles colorées selon
/// rareté sur un fond crème, ancrées avec une carte en surimpression légère.
class _MiniMapMock extends StatelessWidget {
  const _MiniMapMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: 6,
            left: 8,
            child: Icon(Icons.map_outlined, size: 20, color: textMuted),
          ),
          Positioned(top: 12, left: 40, child: _MockDot(color: rarityCommon)),
          Positioned(top: 40, left: 80, child: _MockDot(color: rarityRare)),
          Positioned(bottom: 10, left: 60, child: _MockDot(color: rarityEpic)),
          Positioned(top: 20, right: 40, child: _MockDot(color: rarityRare)),
          Positioned(
              bottom: 8, right: 20, child: _MockDot(color: rarityLegendary)),
          Positioned(top: 50, right: 90, child: _MockDot(color: rarityCommon)),
        ],
      ),
    );
  }
}

class _MockDot extends StatelessWidget {
  const _MockDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: surfaceBase, width: 2),
      ),
    );
  }
}

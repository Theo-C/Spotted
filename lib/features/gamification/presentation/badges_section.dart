import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/gamification_state_provider.dart';
import '../domain/badge.dart';

/// Grille des badges affichée dans le Profil.
/// Groupés par catégorie (Premiers pas / Rareté / Photo / Série).
/// Earned = couleur + date d'unlock ; locked = grisé + progression.
class BadgesSection extends ConsumerWidget {
  const BadgesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return badgesAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: forestGreen),
          ),
        ),
      ),
      error: (e, _) => Text(
        'Badges indisponibles',
        style: GoogleFonts.karla(color: textMuted, fontSize: 12),
      ),
      data: (statuses) {
        final earnedCount = statuses.where((b) => b.isEarned).length;
        // Groupage par catégorie pour l'affichage en sections.
        final byCategory = <BadgeCategory, List<BadgeStatus>>{};
        for (final s in statuses) {
          byCategory.putIfAbsent(s.def.category, () => []).add(s);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête compteur
            Row(
              children: [
                Expanded(
                  child: Text(
                    'BADGES',
                    style: GoogleFonts.karla(
                      fontSize: 10,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                    ),
                  ),
                ),
                Text(
                  '$earnedCount / ${statuses.length}',
                  style: GoogleFonts.karla(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final cat in BadgeCategory.values) ...[
              if (byCategory[cat] != null) ...[
                _CategoryLabel(text: _categoryName(cat)),
                const SizedBox(height: 6),
                _BadgeGrid(items: byCategory[cat]!),
                const SizedBox(height: 14),
              ],
            ],
          ],
        );
      },
    );
  }

  String _categoryName(BadgeCategory c) => switch (c) {
        BadgeCategory.firstSteps => 'Premiers pas',
        BadgeCategory.rarity => 'Rareté',
        BadgeCategory.photo => 'Photographe',
        BadgeCategory.streak => 'Série',
        BadgeCategory.collection => 'Collections',
        BadgeCategory.mystery => 'Mystères',
      };
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: forestGreen,
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.items});
  final List<BadgeStatus> items;

  @override
  Widget build(BuildContext context) {
    // 4 colonnes + tiles plus carrées → ~40% de hauteur en moins vs 3 col.
    // Nécessaire depuis l'ajout de 4 collection + 3 mystères (28 badges au
    // total), sinon la section badges bouffait tout l'écran du Profil.
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.88,
      children: [
        for (final s in items) _BadgeTile(status: s),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.status});
  final BadgeStatus status;

  /// True quand on doit masquer icône/nom/description : badge marqué comme
  /// mystère ET pas encore débloqué. Sinon on révèle tout comme d'habitude.
  bool get _isMasked => status.def.isHidden && !status.isEarned;

  @override
  Widget build(BuildContext context) {
    final earned = status.isEarned;
    final masked = _isMasked;
    final pct = status.progress.value.clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: earned ? surfaceCard : surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned
                ? gold.withValues(alpha: 0.6)
                : textMuted.withValues(alpha: 0.3),
            width: earned ? 1.5 : 1,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mystère : icône atmosphérique dédiée (hiddenIcon) avec une
            // opacité réduite. Fallback ✨ si l'auteur du badge a oublié
            // d'en fournir une. On évite le cadenas Material qui rendait
            // la grille très générique.
            Opacity(
              opacity: masked ? 0.55 : (earned ? 1.0 : 0.5),
              child: Text(
                masked
                    ? (status.def.hiddenIcon ?? '✨')
                    : status.def.icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            Text(
              masked ? 'Mystère' : status.def.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.karla(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: earned ? forestGreen : textSecondary,
                fontStyle: masked ? FontStyle.italic : FontStyle.normal,
                height: 1.15,
              ),
            ),
            if (earned)
              const Icon(Icons.check_circle, size: 12, color: forestGreen)
            else
              // Sur un mystère, la barre trahirait la difficulté. On la
              // masque totalement pour préserver la surprise.
              masked
                  ? const SizedBox(height: 2)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 2.5,
                        backgroundColor: textMuted.withValues(alpha: 0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(terracotta),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceBase,
      useRootNavigator: false,
      // Material 3 cappe la largeur des bottom sheets à 640 par défaut, ce
      // qui laisse des marges "vides" sur les côtés selon la taille du texte
      // affiché. On dé-cappe ici pour occuper toute la largeur.
      constraints: const BoxConstraints(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SizedBox(
          // Ceinture + bretelles : force full-width même si les enfants sont
          // narrow (Column avec crossAxisAlignment.center peut sinon rendre
          // le container tributaire de la largeur du plus large enfant).
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E0CE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Opacity(
                opacity: _isMasked ? 0.6 : 1.0,
                child: Text(
                  _isMasked
                      ? (status.def.hiddenIcon ?? '✨')
                      : status.def.icon,
                  style: const TextStyle(fontSize: 56),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isMasked ? 'Badge mystère' : status.def.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontStyle: _isMasked ? FontStyle.italic : FontStyle.normal,
                  color: forestGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isMasked
                    ? (status.def.hiddenHint ??
                        'Continue à observer — il se dévoilera au bon moment.')
                    : status.def.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.karla(
                  fontSize: 13,
                  color: textPrimary,
                  height: 1.4,
                  fontStyle: _isMasked ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 16),
              if (status.isEarned)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: forestGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Débloqué ${_formatDate(status.earnedAt!)}',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: surfaceBase,
                    ),
                  ),
                )
              else if (!_isMasked) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: status.progress.value.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: textMuted.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(terracotta),
                  ),
                ),
                const SizedBox(height: 6),
                if (status.progress.label != null)
                  Text(
                    status.progress.label!,
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
              ],
            ],
            ),
          ),
        ),
      ),
    );
  }

  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  String _formatDate(DateTime d) {
    final dl = d.toLocal();
    return 'le ${dl.day} ${_months[dl.month - 1]} ${dl.year}';
  }
}

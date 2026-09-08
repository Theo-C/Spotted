import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/rarity.dart';
import '../../territories/data/category_repository.dart';
import '../data/observations_for_map_provider.dart';
import '../data/recent_observations_provider.dart';
import 'observation_detail_sheet.dart';

/// Bloc "Dernières observations" affiché sur la Home entre les quêtes du
/// jour et la liste des terrains. Scroll horizontal de cartes compactes qui
/// donnent une pulse d'activité récente (tes obs uniquement), motive à
/// revenir régulièrement et à réagir en tapant.
///
/// La section est totalement masquée si aucune obs n'existe encore — sinon
/// on affiche un vide muet qui pollue la Home d'un compte fraîchement créé.
class RecentObservationsSection extends ConsumerWidget {
  const RecentObservationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentObservationsProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'DERNIÈRES OBSERVATIONS',
            style: GoogleFonts.karla(
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.bold,
              color: textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _RecentObsCard(item: recent[i]),
          ),
        ),
      ],
    );
  }
}

/// Carte 150×190 : photo (ou emoji fallback) + rareté + nom + date.
/// Depuis la séparation user-to-user, plus d'affichage observer (c'est
/// toujours "toi" par construction).
class _RecentObsCard extends ConsumerWidget {
  const _RecentObsCard({required this.item});

  final ObservationOnMap item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = item.species;
    final rarity = item.rarity;
    final photoUrl = item.obs.photoUrl;
    // Emoji de catégorie en fallback quand pas de photo — cohérent avec le
    // pattern déjà utilisé sur la liste espèces (SpeciesThumbnail).
    // Lookup O(1) dans la map partagée (cachée keepAlive) au lieu d'un
    // FutureProvider.family qui refetch getAll() par carte.
    final categoriesById =
        ref.watch(categoriesByIdProvider).asData?.value ?? const {};
    final iconKey =
        categoriesById[species?.categoryId]?.icon ?? 'birds';

    return _CardShell(
      onTap: () => _openDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardPhoto(
            photoUrl: photoUrl,
            iconKey: iconKey,
            rarity: rarity,
            wasDailySpecies: item.obs.wasDailySpecies,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    species?.commonName ?? 'Espèce inconnue',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: forestGreen,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        DateFormatter.relative(item.obs.observedAt),
                        style: GoogleFonts.karla(
                          fontSize: 9,
                          color: textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '+${item.obs.pointsEarned}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ObservationDetailSheet(item: item),
    );
  }

}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 130,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE8E0CE),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _CardPhoto extends StatelessWidget {
  const _CardPhoto({
    required this.photoUrl,
    required this.iconKey,
    required this.rarity,
    required this.wasDailySpecies,
  });

  final String? photoUrl;
  final String iconKey;
  final Rarity? rarity;
  final bool wasDailySpecies;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    final fallback = Container(
      color: color.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        emojiForCategory(iconKey),
        style: TextStyle(
          fontSize: 32,
          color: color.withValues(alpha: 0.8),
        ),
      ),
    );

    return Stack(
      children: [
        SizedBox(
          height: 85,
          width: double.infinity,
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 280,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                )
              : fallback,
        ),
        if (rarity != null)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: surfaceBase.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1),
              ),
              child: Text(
                _rarityLabel(rarity!).toUpperCase(),
                style: GoogleFonts.karla(
                  fontSize: 8,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        // Étoile "défi du jour" en top-right, opposée à la rareté pour ne
        // pas se marcher dessus. Fond crème pour rester lisible sur photo.
        if (wasDailySpecies)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: surfaceBase.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 1),
              ),
              child: const Icon(Icons.stars, size: 13, color: gold),
            ),
          ),
      ],
    );
  }

  static Color _rarityColor(Rarity? r) => switch (r) {
        Rarity.common => rarityCommon,
        Rarity.rare => rarityRare,
        Rarity.epic => rarityEpic,
        Rarity.legendary => rarityLegendary,
        null => rarityCommon,
      };

  static String _rarityLabel(Rarity r) => switch (r) {
        Rarity.common => 'Commun',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Épique',
        Rarity.legendary => 'Légend.',
      };
}


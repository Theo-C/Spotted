import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/rarity.dart';
import '../../auth/data/auth_providers.dart';
import '../../observations/data/observations_for_map_provider.dart';
import '../../territories/data/category_repository.dart';
import '../data/daily_species_provider.dart';

/// Bandeau "Espèce du jour" sur la Home. Deux états visuels :
///   - À débusquer : gradient gold, chip "×2 aujourd'hui", tap → fiche
///   - Déjà validée aujourd'hui : gradient forestGreen, "+N pts crédités"
///
/// Masqué si le tirage n'est pas encore disponible (zone GPS pas résolue,
/// user pas connecté, catalogue vide). Pas de skeleton — la Home a déjà
/// assez de "loading spinners", un vide silencieux est plus propre.
class DailySpeciesBanner extends ConsumerWidget {
  const DailySpeciesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dsAsync = ref.watch(dailySpeciesProvider);
    final resolved = dsAsync.asData?.value;
    if (resolved == null) return const SizedBox.shrink();

    final observedToday = _isObservedToday(
      ref: ref,
      speciesId: resolved.species.id,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _BannerCard(
        resolved: resolved,
        observedToday: observedToday,
      ),
    );
  }

  /// True si l'user courant a une obs de cette espèce datée d'aujourd'hui.
  /// Lit allObservationsForMapProvider (déjà en cache pour la Home).
  bool _isObservedToday({required WidgetRef ref, required String speciesId}) {
    final userId = ref.watch(currentAuthUserProvider)?.id;
    if (userId == null) return false;
    final all =
        ref.watch(allObservationsForMapProvider).asData?.value ?? const [];
    final now = DateTime.now().toLocal();
    return all.any((i) {
      if (i.obs.userId != userId) return false;
      if (i.obs.speciesId != speciesId) return false;
      final d = i.obs.observedAt.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    });
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard({required this.resolved, required this.observedToday});

  final DailySpeciesResolved resolved;
  final bool observedToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarityColor = _rarityColor(resolved.rarity);
    // Lookup O(1) dans la map partagée (cachée keepAlive) — évite un
    // FutureProvider.family qui refetch getAll() par instance.
    final categoriesById =
        ref.watch(categoriesByIdProvider).asData?.value ?? const {};
    final categoryIconKey =
        categoriesById[resolved.species.categoryId]?.icon ?? 'birds';

    // Palette selon l'état : gold "à débusquer" (invitation) vs forestGreen
    // "validé" (accomplissement). Deux vocabulaires visuels distincts pour
    // que l'user distingue d'un coup d'œil.
    final gradient = observedToday
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [forestGreen, forestGreenLight],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gold, goldLight],
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openSpeciesDetail(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (observedToday ? forestGreen : gold)
                    .withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(observedToday: observedToday),
              const SizedBox(height: 10),
              _Body(
                commonName: resolved.species.commonName,
                scientificName: resolved.species.scientificName,
                iconKey: categoryIconKey,
                rarity: resolved.rarity,
                rarityColor: rarityColor,
                observedToday: observedToday,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSpeciesDetail(BuildContext context) {
    final zoneId = resolved.challenge.zoneId;
    final catId = resolved.species.categoryId;
    if (zoneId == null) return;
    context.go('/territory/$zoneId/category/$catId/species/${resolved.species.id}');
  }

  static Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => rarityCommon,
        Rarity.rare => rarityRare,
        Rarity.epic => rarityEpic,
        Rarity.legendary => rarityLegendary,
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.observedToday});

  final bool observedToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          observedToday
              ? Icons.check_circle_outline
              : Icons.stars_outlined,
          size: 16,
          color: surfaceBase,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            observedToday
                ? 'ESPÈCE DU JOUR VALIDÉE'
                : 'ESPÈCE DU JOUR',
            style: GoogleFonts.karla(
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.bold,
              color: surfaceBase,
            ),
          ),
        ),
        if (!observedToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: surfaceBase.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '×2 AUJOURD\'HUI',
              style: GoogleFonts.karla(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: forestGreen,
              ),
            ),
          ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.commonName,
    required this.scientificName,
    required this.iconKey,
    required this.rarity,
    required this.rarityColor,
    required this.observedToday,
  });

  final String commonName;
  final String scientificName;
  final String iconKey;
  final Rarity rarity;
  final Color rarityColor;
  final bool observedToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Bulle avec emoji catégorie — cache l'espèce visuellement (comme
        // dans la liste "mystères") : l'user tape pour voir la photo.
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: surfaceBase.withValues(alpha: 0.95),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            emojiForCategory(iconKey),
            style: const TextStyle(fontSize: 30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                commonName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: surfaceBase,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                scientificName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: surfaceBase.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 6),
              _RarityChip(rarity: rarity, color: rarityColor),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(
          Icons.chevron_right,
          size: 24,
          color: surfaceBase,
        ),
      ],
    );
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity, required this.color});

  final Rarity rarity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: surfaceBase.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        _label(rarity).toUpperCase(),
        style: GoogleFonts.karla(
          fontSize: 9,
          letterSpacing: 1.3,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static String _label(Rarity r) => switch (r) {
        Rarity.common => 'Commun',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Épique',
        Rarity.legendary => 'Légend.',
      };
}


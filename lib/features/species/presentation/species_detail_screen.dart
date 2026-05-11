import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/rarity.dart';
import '../../auth/data/auth_providers.dart';
import '../../gamification/domain/points.dart';
import '../../observations/data/observations_for_map_provider.dart';
import '../../observations/data/observed_species_provider.dart';
import '../../observations/presentation/observation_detail_sheet.dart';
import '../../territories/data/geocoding_service.dart';
import '../../territories/data/category_repository.dart';
import '../data/species_detail_provider.dart';
import '../data/species_with_rarity_provider.dart';

class SpeciesDetailScreen extends ConsumerWidget {
  const SpeciesDetailScreen({
    super.key,
    required this.zoneId,
    required this.speciesId,
  });

  final String zoneId;
  final String speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      speciesDetailProvider(
        (zoneId: zoneId, speciesId: speciesId),
      ),
    );
    final observedIdsAsync =
        ref.watch(observedSpeciesIdsInZoneProvider(zoneId));

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'Espèce introuvable',
              style: GoogleFonts.karla(color: textMuted),
            ),
          ),
        ),
        data: (detail) {
          final isObserved =
              observedIdsAsync.asData?.value.contains(speciesId) ?? false;
          return _DetailBody(
            detail: detail,
            isObserved: isObserved,
            ref: ref,
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.isObserved,
    required this.ref,
  });

  final SpeciesWithRarity detail;
  final bool isObserved;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final categoryAsync =
        ref.watch(_categoryByIdProvider(detail.species.categoryId));
    final categoryIconKey =
        categoryAsync.asData?.value.icon ?? 'birds';
    final categoryName = categoryAsync.asData?.value.name ?? '';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Hero(
            rarity: detail.rarity,
            iconKey: categoryIconKey,
            isObserved: isObserved,
            speciesId: detail.species.id,
            photoUrl: detail.species.photoUrl,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RarityStars(rarity: detail.rarity),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        categoryName.toUpperCase(),
                        style: GoogleFonts.karla(
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detail.species.commonName,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: isObserved ? forestGreen : textSecondary,
                    height: 1.05,
                  ),
                ),
                Text(
                  detail.species.scientificName,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: isObserved ? terracotta : textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                _StatsRow(rarity: detail.rarity, isObserved: isObserved),
                const SizedBox(height: 20),
                Text(
                  isObserved ? 'DESCRIPTION' : 'FICHE GUIDE DE TERRAIN',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.species.description ??
                      'Pas de description disponible.',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 15,
                    color: textPrimary,
                    height: 1.5,
                  ),
                ),
                if (isObserved) ...[
                  const SizedBox(height: 20),
                  _MyObservationsSection(speciesId: detail.species.id),
                ],
                if (!isObserved && detail.species.tips != null) ...[
                  const SizedBox(height: 16),
                  _SpottingTipsCard(
                    tips: detail.species.tips!,
                    rarity: detail.rarity,
                  ),
                ],
                const SizedBox(height: 24),
                if (!isObserved)
                  _ObserveButton(
                    rarity: detail.rarity,
                    onTap: () {
                      context.push(
                        '/observation/new?species=${detail.species.id}',
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final _categoryByIdProvider = FutureProvider.family((ref, String id) async {
  final categories = await ref.watch(categoryRepositoryProvider).getAll();
  return categories.firstWhere((c) => c.id == id);
});

class _Hero extends StatelessWidget {
  const _Hero({
    required this.rarity,
    required this.iconKey,
    required this.isObserved,
    required this.speciesId,
    required this.photoUrl,
  });

  final Rarity rarity;
  final String iconKey;
  final bool isObserved;
  final String speciesId;

  /// URL de la photo d'illustration de l'espèce (catalogue). Si présente,
  /// remplace l'emoji par défaut. Si null, fallback emoji + gradient rareté.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    final hasPhoto = photoUrl != null;
    return SizedBox(
      height: 256,
      child: Stack(
        children: [
          // Fond : gradient rareté toujours en arrière-plan, sert aussi de
          // fallback si l'image réseau échoue à charger.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.85)],
                ),
              ),
            ),
          ),
          if (hasPhoto) ...[
            // Backdrop : photo en cover et floutée pour remplir tout le hero.
            // Évite les bandes mortes des photos portrait/carrées tout en
            // gardant un fond cohérent qui reprend les couleurs de l'image.
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Voile rareté entre backdrop et foreground — signal "à débusquer"
            // visible dans les marges autour de la photo nette.
            if (!isObserved)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                  ),
                ),
              ),
            // Foreground : photo nette en contain, animal toujours visible
            // dans son entier, recadrage non destructif.
            Positioned.fill(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ] else
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: isObserved ? 0.85 : 0.55,
                  child: Text(
                    emojiForCategory(iconKey),
                    style: const TextStyle(fontSize: 120),
                  ),
                ),
              ),
            ),
          // Back button
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: _CircleButton(
                icon: Icons.chevron_left,
                onTap: () => context.pop(),
              ),
            ),
          ),
          // Rarity badge + edit button
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.edit_outlined,
                    onTap: () => context.push('/species/$speciesId/edit'),
                  ),
                  const SizedBox(width: 8),
                  _RarityBadge(rarity: rarity),
                ],
              ),
            ),
          ),
          // "À débusquer"
          if (!isObserved)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: surfaceBase.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Text(
                  'À DÉBUSQUER',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceBase.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: forestGreen, size: 20),
        ),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});

  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        _label(rarity).toUpperCase(),
        style: GoogleFonts.karla(
          fontSize: 11,
          letterSpacing: 1.5,
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
        Rarity.legendary => 'Légendaire',
      };
}

class _RarityStars extends StatelessWidget {
  const _RarityStars({required this.rarity});

  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    final stars = rarityStars(rarity);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            i < stars ? Icons.star : Icons.star_outline,
            size: 12,
            color: i < stars ? color : const Color(0xFFD5CDB8),
          ),
        );
      }),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.rarity, required this.isObserved});

  final Rarity rarity;
  final bool isObserved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.auto_awesome,
            iconColor: gold,
            label: 'Points',
            value: '+${firstObservationPoints(rarity)}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.camera_alt_outlined,
            iconColor: terracotta,
            label: 'Bonus photo',
            value: '+50%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.visibility_outlined,
            iconColor: isObserved ? goldLight : textSecondary,
            label: 'Statut',
            value: isObserved ? 'Vue ✓' : '—',
            highlighted: isObserved,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? forestGreen : surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? forestGreen : const Color(0xFFE8E0CE),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.karla(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: highlighted
                  ? const Color(0xFFC4A572)
                  : textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: highlighted ? surfaceBase : forestGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte "Pour la débusquer" — conseil terrain affiché sur la fiche d'une
/// espèce non encore observée. Bordure et accents dans la couleur de rareté
/// pour rappeler le niveau de difficulté de l'obs à venir.
class _SpottingTipsCard extends StatelessWidget {
  const _SpottingTipsCard({required this.tips, required this.rarity});

  final String tips;
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.center_focus_strong, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POUR LA DÉBUSQUER',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tips,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    color: textPrimary,
                    height: 1.4,
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

class _ObserveButton extends StatelessWidget {
  const _ObserveButton({required this.rarity, required this.onTap});

  final Rarity rarity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    return Material(
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: surfaceBase,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "JE L'AI VUE !",
                style: GoogleFonts.karla(
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: surfaceBase,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste les observations de l'utilisateur courant pour cette espèce.
/// Affichée sur la fiche détail dès qu'au moins une obs existe (isObserved).
/// Triée par date croissante — la 1ʳᵉ obs porte un badge "1ʳᵉ".
class _MyObservationsSection extends ConsumerWidget {
  const _MyObservationsSection({required this.speciesId});

  final String speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allObsAsync = ref.watch(allObservationsForMapProvider);
    final currentUserId = ref.watch(currentAuthUserProvider)?.id;
    if (currentUserId == null) return const SizedBox.shrink();

    return allObsAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        final mine = all
            .where((i) =>
                i.obs.speciesId == speciesId && i.obs.userId == currentUserId)
            .toList()
          ..sort((a, b) => a.obs.observedAt.compareTo(b.obs.observedAt));
        if (mine.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MES OBSERVATIONS · ${mine.length}',
              style: GoogleFonts.karla(
                fontSize: 10,
                letterSpacing: 2.5,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < mine.length; i++) ...[
              _MyObservationCard(item: mine[i]),
              if (i < mine.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _MyObservationCard extends ConsumerWidget {
  const _MyObservationCard({required this.item});

  final ObservationOnMap item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFirst = item.obs.isFirstForUser;
    final hasPhoto = item.obs.photoUrl != null;
    final geocodingAsync = ref.watch(
      reverseGeocodingProvider(
        (lat: item.obs.latitude, lng: item.obs.longitude),
      ),
    );
    // Priorité d'affichage : commune (compact pour la carte) > displayName
    // complet > fallback coords courts pendant le chargement / erreur réseau.
    final placeText = geocodingAsync.asData?.value?.place ??
        geocodingAsync.asData?.value?.displayName ??
        '${item.obs.latitude.toStringAsFixed(4)}, '
            '${item.obs.longitude.toStringAsFixed(4)}';
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: surfaceBase,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => ObservationDetailSheet(
          item: item,
          // On est déjà sur la fiche détail de l'espèce → masquer le bouton
          // "Voir la fiche d'espèce" qui serait redondant.
          showOpenSpeciesButton: false,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isFirst ? forestGreen : surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFirst ? forestGreen : const Color(0xFFE8E0CE),
            width: 1.5,
          ),
        ),
        child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: hasPhoto
                  ? Image.network(
                      item.obs.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _ThumbFallback(
                        isFirst: isFirst,
                        icon: Icons.broken_image_outlined,
                      ),
                    )
                  : _ThumbFallback(
                      isFirst: isFirst,
                      icon: Icons.location_on,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isFirst) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: goldLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '1ʳᵉ',
                          style: GoogleFonts.karla(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: forestGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        DateFormat('d MMM yyyy', 'fr')
                            .format(item.obs.observedAt),
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isFirst ? surfaceBase : forestGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 11,
                      color: isFirst
                          ? const Color(0xFFC4A572)
                          : textMuted,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        placeText,
                        style: GoogleFonts.karla(
                          fontSize: 10,
                          color: isFirst
                              ? const Color(0xFFC4A572)
                              : textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${item.obs.pointsEarned}',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isFirst ? goldLight : gold,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.isFirst, required this.icon});

  final bool isFirst;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isFirst ? surfaceBase.withValues(alpha: 0.15) : surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 18,
        color: isFirst ? goldLight : textSecondary,
      ),
    );
  }
}

Color _rarityColor(Rarity r) => switch (r) {
      Rarity.common => rarityCommon,
      Rarity.rare => rarityRare,
      Rarity.epic => rarityEpic,
      Rarity.legendary => rarityLegendary,
    };

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/rarity.dart';
import '../../gamification/domain/points.dart';
import '../../observations/data/observed_species_provider.dart';
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
          if (hasPhoto)
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: isObserved
                    ? const ColorFilter.mode(
                        Colors.transparent, BlendMode.dst)
                    : ColorFilter.mode(
                        color.withValues(alpha: 0.35),
                        BlendMode.darken,
                      ),
                child: Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            )
          else
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
          // Fade vers la surface
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 48,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, surfaceBase],
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

Color _rarityColor(Rarity r) => switch (r) {
      Rarity.common => rarityCommon,
      Rarity.rare => rarityRare,
      Rarity.epic => rarityEpic,
      Rarity.legendary => rarityLegendary,
    };

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/rarity.dart';
import '../../observations/data/observed_species_provider.dart';
import '../../territories/data/category_repository.dart';
import '../data/species_with_rarity_provider.dart';

enum _StatusFilter { all, observed, mystery }

class SpeciesListScreen extends ConsumerStatefulWidget {
  const SpeciesListScreen({
    super.key,
    required this.zoneId,
    required this.categoryId,
  });

  final String zoneId;
  final String categoryId;

  @override
  ConsumerState<SpeciesListScreen> createState() => _SpeciesListScreenState();
}

class _SpeciesListScreenState extends ConsumerState<SpeciesListScreen> {
  _StatusFilter _status = _StatusFilter.all;
  Rarity? _rarity; // null = toutes raretés

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(_categoryByIdProvider(widget.categoryId));
    final speciesAsync = ref.watch(
      speciesByCategoryInZoneProvider(
        (zoneId: widget.zoneId, categoryId: widget.categoryId),
      ),
    );
    final observedIdsAsync = ref.watch(
      observedSpeciesIdsInZoneProvider(widget.zoneId),
    );

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.chevron_left, color: forestGreen),
                    label: Text(
                      'Oise',
                      style: GoogleFonts.karla(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: forestGreen,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: categoryAsync.when(
                  loading: () => const SizedBox(height: 60),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (category) {
                  final speciesInCategory =
                      speciesAsync.asData?.value ?? const [];
                  final observedIds =
                      observedIdsAsync.asData?.value ?? const <String>{};
                  final observedInCategory = speciesInCategory
                      .where((s) => observedIds.contains(s.species.id))
                      .length;
                  return _CategoryHeader(
                    category: category,
                    observed: observedInCategory,
                    total: speciesInCategory.length,
                  );
                },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: _StatusFilters(
                  current: _status,
                  onChanged: (f) => setState(() => _status = f),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: _RarityFilters(
                  current: _rarity,
                  onChanged: (r) => setState(() => _rarity = r),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              sliver: speciesAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Erreur de chargement',
                        style: GoogleFonts.karla(color: textMuted),
                      ),
                    ),
                  ),
                ),
                data: (allItems) {
                  final observed = observedIdsAsync.asData?.value ?? <String>{};
                  final filtered = allItems.where((it) {
                    if (_rarity != null && it.rarity != _rarity) return false;
                    final isObserved = observed.contains(it.species.id);
                    if (_status == _StatusFilter.observed && !isObserved) {
                      return false;
                    }
                    if (_status == _StatusFilter.mystery && isObserved) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'Aucune espèce avec ces filtres.',
                            style: GoogleFonts.karla(
                              fontSize: 13,
                              color: textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final categoryIcon =
                      categoryAsync.asData?.value.icon ?? 'birds';
                  return SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return _SpeciesCard(
                        species: item.species,
                        rarity: item.rarity,
                        categoryIconKey: categoryIcon,
                        observed: observed.contains(item.species.id),
                        onTap: () {
                          context.go(
                            '/territory/${widget.zoneId}/category/${widget.categoryId}/species/${item.species.id}',
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _categoryByIdProvider = FutureProvider.family((ref, String id) async {
  final categories = await ref.watch(categoryRepositoryProvider).getAll();
  return categories.firstWhere((c) => c.id == id);
});

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    required this.observed,
    required this.total,
  });

  final Category category;
  final int observed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emojiForCategory(category.icon), style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: forestGreen,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$observed / $total DÉCOUVERTES',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: terracotta,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.current, required this.onChanged});

  final _StatusFilter current;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E0CE)),
      ),
      child: Row(
        children: [
          for (final f in _StatusFilter.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == f ? forestGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _label(f),
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: current == f ? surfaceBase : textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(_StatusFilter f) {
    return switch (f) {
      _StatusFilter.all => 'Tout',
      _StatusFilter.observed => '✓ Vues',
      _StatusFilter.mystery => 'Mystères',
    };
  }
}

class _RarityFilters extends StatelessWidget {
  const _RarityFilters({required this.current, required this.onChanged});

  final Rarity? current;
  final ValueChanged<Rarity?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _Chip(
          label: 'Toutes',
          selected: current == null,
          onTap: () => onChanged(null),
        ),
        for (final r in Rarity.values) ...[
          const SizedBox(width: 8),
          _Chip(
            label: _rarityLabel(r),
            selected: current == r,
            color: _rarityColor(r),
            onTap: () => onChanged(r),
          ),
        ],
      ],
    );
  }

  static String _rarityLabel(Rarity r) {
    return switch (r) {
      Rarity.common => 'Commun',
      Rarity.rare => 'Rare',
      Rarity.epic => 'Épique',
      Rarity.legendary => 'Légendaire',
    };
  }

  static Color _rarityColor(Rarity r) {
    return switch (r) {
      Rarity.common => rarityCommon,
      Rarity.rare => rarityRare,
      Rarity.epic => rarityEpic,
      Rarity.legendary => rarityLegendary,
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = forestGreen,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.karla(
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: selected ? surfaceBase : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({
    required this.species,
    required this.rarity,
    required this.categoryIconKey,
    required this.observed,
    required this.onTap,
  });

  final dynamic species; // Species
  final Rarity rarity;
  final String categoryIconKey;
  final bool observed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    return Material(
      color: observed ? surfaceCard : surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: observed ? forestGreen : color,
              width: 2,
              style: observed ? BorderStyle.solid : BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.15),
                          color.withValues(alpha: 0.35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        emojiForCategory(categoryIconKey),
                        style: TextStyle(
                          fontSize: 26,
                          color: observed ? null : color.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  if (observed)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: forestGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceBase, width: 2),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: surfaceBase,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      species.commonName as String,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: observed ? forestGreen : textSecondary,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      species.scientificName as String,
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: observed ? terracotta : textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _RarityPill(rarity: rarity),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _rarityColor(Rarity r) {
    return switch (r) {
      Rarity.common => rarityCommon,
      Rarity.rare => rarityRare,
      Rarity.epic => rarityEpic,
      Rarity.legendary => rarityLegendary,
    };
  }
}

class _RarityPill extends StatelessWidget {
  const _RarityPill({required this.rarity});

  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        _label(rarity).toUpperCase(),
        style: GoogleFonts.karla(
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static String _label(Rarity r) {
    return switch (r) {
      Rarity.common => 'Commun',
      Rarity.rare => 'Rare',
      Rarity.epic => 'Épique',
      Rarity.legendary => 'Légendaire',
    };
  }

  static Color _rarityColor(Rarity r) {
    return switch (r) {
      Rarity.common => rarityCommon,
      Rarity.rare => rarityRare,
      Rarity.epic => rarityEpic,
      Rarity.legendary => rarityLegendary,
    };
  }
}

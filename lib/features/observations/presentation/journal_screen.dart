import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/category.dart' as model;
import '../../../shared/models/rarity.dart';
import '../../../shared/providers/observer_provider.dart';
import '../../territories/data/category_repository.dart';
import '../data/observations_for_map_provider.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  CircleAnnotationManager? _circleManager;

  /// Mapping annotation ID → observation, pour résoudre le tap.
  final Map<String, ObservationOnMap> _byAnnotationId = {};

  // Filtres actifs (null = pas de filtre).
  String? _categoryFilter; // category.id
  Rarity? _rarityFilter;
  String? _observerFilter; // user.id

  Future<void> _onMapCreated(MapboxMap map) async {
    _circleManager = await map.annotations.createCircleAnnotationManager();
    _circleManager!.tapEvents(onTap: _handleAnnotationTap);
    // Échelle déplacée en bas à droite — par défaut top-left, masquée par
    // notre barre de filtres. Logo + attribution Mapbox restent bottom-left.
    await map.scaleBar.updateSettings(
      ScaleBarSettings(position: OrnamentPosition.BOTTOM_RIGHT),
    );
    await _renderAnnotations();
  }

  /// Recharge tous les markers depuis le provider, en appliquant les filtres.
  /// Idempotent — supprime d'abord les annotations existantes.
  Future<void> _renderAnnotations() async {
    final manager = _circleManager;
    if (manager == null) return;
    final asyncItems = ref.read(allObservationsForMapProvider);
    final allItems = asyncItems.asData?.value;
    if (allItems == null) return;

    final filtered = allItems.where(_matchesFilters).toList();

    await manager.deleteAll();
    _byAnnotationId.clear();
    for (final item in filtered) {
      final colorInt = _rarityColorInt(item.rarity);
      final annotation = await manager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.obs.longitude, item.obs.latitude),
          ),
          circleRadius: 8,
          circleColor: colorInt,
          circleStrokeWidth: 2,
          circleStrokeColor: 0xFFFAF6EC,
        ),
      );
      _byAnnotationId[annotation.id] = item;
    }
  }

  bool _matchesFilters(ObservationOnMap item) {
    if (_categoryFilter != null &&
        item.species?.categoryId != _categoryFilter) {
      return false;
    }
    if (_rarityFilter != null && item.rarity != _rarityFilter) return false;
    if (_observerFilter != null && item.obs.userId != _observerFilter) {
      return false;
    }
    return true;
  }

  bool _handleAnnotationTap(CircleAnnotation annotation) {
    final item = _byAnnotationId[annotation.id];
    if (item == null) return false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ObservationDetailSheet(item: item),
    );
    return true;
  }

  static int _rarityColorInt(Rarity? r) {
    return switch (r) {
      Rarity.common => 0xFF7A7569,
      Rarity.rare => 0xFF2D6E8C,
      Rarity.epic => 0xFF7A3D9A,
      Rarity.legendary => 0xFFC49120,
      null => 0xFF7A7569,
    };
  }

  void _setCategoryFilter(String? id) {
    setState(() => _categoryFilter = id);
    _renderAnnotations();
  }

  void _setRarityFilter(Rarity? r) {
    setState(() => _rarityFilter = r);
    _renderAnnotations();
  }

  void _setObserverFilter(String? id) {
    setState(() => _observerFilter = id);
    _renderAnnotations();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(allObservationsForMapProvider, (_, _) {
      _renderAnnotations();
    });

    final allItems =
        ref.watch(allObservationsForMapProvider).asData?.value ?? const [];
    final visibleCount = allItems.where(_matchesFilters).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Carnet',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
      ),
      body: Stack(
        children: [
          MapWidget(
            viewport: CameraViewportState(
              center: Point(coordinates: Position(2.82, 49.41)),
              zoom: 9.0,
            ),
            styleUri: MapboxStyles.OUTDOORS,
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FiltersBar(
              categoryFilter: _categoryFilter,
              rarityFilter: _rarityFilter,
              observerFilter: _observerFilter,
              visibleCount: visibleCount,
              totalCount: allItems.length,
              onCategoryChanged: _setCategoryFilter,
              onRarityChanged: _setRarityFilter,
              onObserverChanged: _setObserverFilter,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends ConsumerWidget {
  const _FiltersBar({
    required this.categoryFilter,
    required this.rarityFilter,
    required this.observerFilter,
    required this.visibleCount,
    required this.totalCount,
    required this.onCategoryChanged,
    required this.onRarityChanged,
    required this.onObserverChanged,
  });

  final String? categoryFilter;
  final Rarity? rarityFilter;
  final String? observerFilter;
  final int visibleCount;
  final int totalCount;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<Rarity?> onRarityChanged;
  final ValueChanged<String?> onObserverChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_categoriesProvider);
    final observersAsync = ref.watch(observersProvider);

    return Container(
      decoration: BoxDecoration(
        color: surfaceBase.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compteur
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: terracotta),
              const SizedBox(width: 4),
              Text(
                '$visibleCount / $totalCount obs.',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Catégories
          categoriesAsync.when(
            loading: () => const SizedBox(height: 28),
            error: (_, _) => const SizedBox.shrink(),
            data: (cats) => _ChipsRow(
              children: [
                _FilterChip(
                  label: 'Toutes',
                  selected: categoryFilter == null,
                  onTap: () => onCategoryChanged(null),
                ),
                for (final c in cats)
                  _FilterChip(
                    label: '${emojiForCategory(c.icon)} ${c.name}',
                    selected: categoryFilter == c.id,
                    onTap: () => onCategoryChanged(c.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Raretés
          _ChipsRow(
            children: [
              _FilterChip(
                label: 'Toutes raretés',
                selected: rarityFilter == null,
                onTap: () => onRarityChanged(null),
              ),
              for (final r in Rarity.values)
                _FilterChip(
                  label: _rarityLabel(r),
                  selected: rarityFilter == r,
                  color: _rarityColor(r),
                  onTap: () => onRarityChanged(r),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Observateurs
          observersAsync.when(
            loading: () => const SizedBox(height: 28),
            error: (_, _) => const SizedBox.shrink(),
            data: (users) => _ChipsRow(
              children: [
                _FilterChip(
                  label: 'Tous obs.',
                  selected: observerFilter == null,
                  onTap: () => onObserverChanged(null),
                ),
                for (final u in users)
                  _FilterChip(
                    label: u.pseudo,
                    selected: observerFilter == u.id,
                    color: Color(
                      int.parse(u.colorAccent.replaceFirst('#', '0xFF')),
                    ),
                    onTap: () => onObserverChanged(u.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _rarityLabel(Rarity r) => switch (r) {
        Rarity.common => 'Commun',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Épique',
        Rarity.legendary => 'Légendaire',
      };

  static Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => rarityCommon,
        Rarity.rare => rarityRare,
        Rarity.epic => rarityEpic,
        Rarity.legendary => rarityLegendary,
      };
}

final _categoriesProvider = FutureProvider<List<model.Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getAll();
});

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.karla(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? surfaceBase : color,
          ),
        ),
      ),
    );
  }
}

class _ObservationDetailSheet extends StatelessWidget {
  const _ObservationDetailSheet({required this.item});

  final ObservationOnMap item;

  @override
  Widget build(BuildContext context) {
    final species = item.species;
    final rarity = item.rarity;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E0CE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (item.obs.photoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    item.obs.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: surfaceMuted,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined,
                          color: textMuted, size: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              species?.commonName ?? 'Espèce inconnue',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: forestGreen,
                height: 1.1,
              ),
            ),
            if (species != null)
              Text(
                species.scientificName,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: terracotta,
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  icon: Icons.calendar_today,
                  label: DateFormat('d MMM yyyy', 'fr')
                      .format(item.obs.observedAt),
                ),
                _Chip(
                  icon: Icons.auto_awesome,
                  label: '+${item.obs.pointsEarned} pts',
                  color: gold,
                ),
                if (rarity != null)
                  _Chip(
                    icon: Icons.star,
                    label: _ObservationDetailSheet._rarityLabel(rarity),
                    color: _ObservationDetailSheet._rarityColor(rarity),
                  ),
                if (item.obs.isFirstForUser)
                  _Chip(
                    icon: Icons.flag,
                    label: '1ʳᵉ obs',
                    color: forestGreen,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${item.obs.latitude.toStringAsFixed(5)}, ${item.obs.longitude.toStringAsFixed(5)}',
              style: GoogleFonts.karla(
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _rarityLabel(Rarity r) => switch (r) {
        Rarity.common => 'Commun',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Épique',
        Rarity.legendary => 'Légendaire',
      };

  static Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => rarityCommon,
        Rarity.rare => rarityRare,
        Rarity.epic => rarityEpic,
        Rarity.legendary => rarityLegendary,
      };
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.color = forestGreen,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.karla(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

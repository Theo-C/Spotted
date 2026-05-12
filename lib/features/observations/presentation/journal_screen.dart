import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// Mapbox SDK exporte un type `Size` qui shadow celui de Flutter — on l'écarte
// pour pouvoir continuer à utiliser le Size de Flutter (Size.zero, etc.).
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../app/theme.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/category.dart' as model;
import '../../../shared/models/rarity.dart';
import '../../../shared/providers/observer_provider.dart';
import '../../territories/data/category_repository.dart';
import '../data/observations_for_map_provider.dart';
import 'observation_detail_sheet.dart';

/// Carnet géo : carte Mapbox avec les obs sous forme de points clustérisés.
///
/// Architecture du rendu (vs ancien CircleAnnotationManager) :
/// - Une source GeoJSON `obs` avec `cluster: true` (clusterMaxZoom: 14)
/// - 3 layers : obs-clusters (cercles), obs-cluster-count (texte du nombre),
///   obs-point (cercles individuels colorés selon la rareté)
/// - Tap : on query les features rendues à l'écran ; si cluster → zoom vers
///   l'expansion zoom natif, si point → bottom sheet de détail.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  MapboxMap? _map;

  /// Index obs_id → ObservationOnMap, pour résoudre le tap sur un point
  /// individuel sans devoir refaire un round-trip BDD.
  final Map<String, ObservationOnMap> _byObsId = {};

  // Filtres (null = pas de filtre).
  String? _categoryFilter;
  Rarity? _rarityFilter;
  String? _observerFilter;

  /// État de la barre de filtres (collapsed par défaut pour ne pas bouffer
  /// 110 px de carte comme avant).
  bool _filtersOpen = false;

  /// Style courant (cycle outdoors → satellite-streets → standard via le
  /// bouton "Layers"). Re-attache la source + les layers à chaque switch
  /// dans _onStyleLoaded (le style wipe les layers custom).
  String _styleUri = MapboxStyles.OUTDOORS;

  /// Viewport mémoïsé : à chaque setState (changement de filtre), une nouvelle
  /// instance ferait que Mapbox ré-applique le viewport (par identité) et
  /// reset la caméra. On le construit une fois.
  late final CameraViewportState _initialViewport;

  static const _sourceId = 'obs';
  static const _layerClusters = 'obs-clusters';
  static const _layerClusterCount = 'obs-cluster-count';
  static const _layerPoint = 'obs-point';

  @override
  void initState() {
    super.initState();
    _initialViewport = CameraViewportState(
      center: Point(coordinates: Position(2.82, 49.41)),
      zoom: 9.0,
    );
  }

  // -------------------------------------------------------------
  // Setup Mapbox
  // -------------------------------------------------------------

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    // Tap → on query les features sous le doigt et on route vers cluster
    // (zoom-in) ou point individuel (bottom sheet). Pattern non-deprecated
    // de Mapbox 2.x.
    map.addInteraction(TapInteraction.onMap(_onMapTap));
  }

  /// Appelé à chaque style load (initial + après loadStyleURI). On (ré)ajoute
  /// la source clustérisée et les 3 layers. Idempotent : on vérifie l'existence
  /// avant d'ajouter (le 1er style load arrive parfois 2× sur Android).
  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;

    final sourceExists = await map.style.styleSourceExists(_sourceId);
    if (!sourceExists) {
      await map.style.addSource(GeoJsonSource(
        id: _sourceId,
        data: _emptyGeoJson(),
        cluster: true,
        clusterRadius: 50,
        clusterMaxZoom: 14,
      ));
    }

    final clustersExists = await map.style.styleLayerExists(_layerClusters);
    if (!clustersExists) {
      // Cercle des clusters : couleur + taille augmentent par paliers.
      await map.style.addLayer(CircleLayer(
        id: _layerClusters,
        sourceId: _sourceId,
        filter: ['has', 'point_count'],
        circleColorExpression: [
          'step',
          ['get', 'point_count'],
          '#B8624A', // 1..4 → terracotta
          5,
          '#A04A30', // 5..19 → terracotta foncé
          20,
          '#1F3D2E', // 20+ → forest green
        ],
        circleRadiusExpression: [
          'step',
          ['get', 'point_count'],
          16.0,
          5,
          22.0,
          20,
          28.0,
        ],
        circleStrokeColor: 0xFFFAF6EC,
        circleStrokeWidth: 3,
      ));
    }

    final countExists = await map.style.styleLayerExists(_layerClusterCount);
    if (!countExists) {
      await map.style.addLayer(SymbolLayer(
        id: _layerClusterCount,
        sourceId: _sourceId,
        filter: ['has', 'point_count'],
        textField: '{point_count_abbreviated}',
        textSize: 13,
        textColor: 0xFFFAF6EC,
      ));
    }

    final pointExists = await map.style.styleLayerExists(_layerPoint);
    if (!pointExists) {
      await map.style.addLayer(CircleLayer(
        id: _layerPoint,
        sourceId: _sourceId,
        filter: ['!', ['has', 'point_count']],
        circleColorExpression: [
          'match',
          ['get', 'rarity'],
          'common', '#7A7569',
          'rare', '#2D6E8C',
          'epic', '#7A3D9A',
          'legendary', '#C49120',
          '#7A7569',
        ],
        circleRadius: 8,
        circleStrokeColor: 0xFFFAF6EC,
        circleStrokeWidth: 2,
      ));
    }

    // Pousse les données courantes (filtre appliqué).
    await _refreshSource();
  }

  /// Recalcule la GeoJSON FeatureCollection à partir du provider et la pousse
  /// dans la source. Met aussi à jour l'index _byObsId.
  Future<void> _refreshSource() async {
    final map = _map;
    if (map == null) return;
    final exists = await map.style.styleSourceExists(_sourceId);
    if (!exists) return;

    final allItems =
        ref.read(allObservationsForMapProvider).asData?.value ?? const [];
    final filtered = allItems.where(_matchesFilters).toList();

    _byObsId
      ..clear()
      ..addEntries(filtered.map((i) => MapEntry(i.obs.id, i)));

    final features = filtered.map((i) => {
          'type': 'Feature',
          'properties': {
            'obs_id': i.obs.id,
            'rarity': i.rarity?.name ?? 'common',
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [i.obs.longitude, i.obs.latitude],
          },
        }).toList();

    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    await map.style.setStyleSourceProperty(_sourceId, 'data', geoJson);
  }

  String _emptyGeoJson() => jsonEncode({
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      });

  // -------------------------------------------------------------
  // Tap handler — cluster ou point individuel
  // -------------------------------------------------------------

  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    final map = _map;
    if (map == null) return;

    // Tolérance tactile : 12 px autour du point de tap (au lieu d'un seul
    // pixel) — un cluster ou un point individuel ne fait que 16-28 px,
    // facile à rater au doigt si la cible est exacte.
    const tol = 12.0;
    final touch = ctx.touchPosition;
    final box = ScreenBox(
      min: ScreenCoordinate(x: touch.x - tol, y: touch.y - tol),
      max: ScreenCoordinate(x: touch.x + tol, y: touch.y + tol),
    );
    final results = await map.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenBox(box),
      RenderedQueryOptions(
        layerIds: [_layerClusters, _layerPoint],
        filter: null,
      ),
    );

    for (final result in results) {
      if (result == null) continue;
      final layers = result.layers;
      final feature = result.queriedFeature.feature;

      if (layers.contains(_layerClusters)) {
        await _zoomToCluster(feature);
        return;
      }
      if (layers.contains(_layerPoint)) {
        await _openPointDetail(feature);
        return;
      }
    }
  }

  Future<void> _zoomToCluster(Map<Object?, Object?> feature) async {
    final map = _map;
    if (map == null) return;
    final ext = await map.getGeoJsonClusterExpansionZoom(
      _sourceId,
      // L'API attend Map<String?, Object?> — feature est Map<Object?, Object?>
      // côté pigeon, cast direct OK car les clés sont des Strings.
      feature.cast<String?, Object?>(),
    );
    // FeatureExtensionValue.value est typé String? côté Mapbox — la lib
    // JSON-encode le retour des extensions. On parse en double.
    final zoom = double.tryParse(ext.value ?? '');
    final coords = ((feature['geometry'] as Map?)?['coordinates'] as List?)
        ?.cast<num>();
    if (zoom == null || coords == null || coords.length < 2) return;

    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(coords[0], coords[1])),
        zoom: zoom + 0.3, // +0.3 pour bien éclater le cluster
      ),
      MapAnimationOptions(duration: 400),
    );
  }

  Future<void> _openPointDetail(Map<Object?, Object?> feature) async {
    final props = (feature['properties'] as Map?)?.cast<String, Object?>();
    final obsId = props?['obs_id'] as String?;
    if (obsId == null) return;
    final item = _byObsId[obsId];
    if (item == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ObservationDetailSheet(item: item),
    );
  }

  // -------------------------------------------------------------
  // Boutons flottants
  // -------------------------------------------------------------

  Future<void> _centerOnUser() async {
    final result =
        await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;
    switch (result) {
      case LocationSuccess(:final lat, :final lng):
        await _map?.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: 13,
          ),
          MapAnimationOptions(duration: 600),
        );
      case LocationServiceDisabled():
        _snackbar('Active la localisation dans tes réglages système.');
      case LocationDenied():
        _snackbar('Permission refusée.');
      case LocationDeniedForever():
        _snackbar(
          'Permission refusée. Active-la dans Réglages → Apps → Spotted → Autorisations.',
        );
      case LocationError(:final message):
        _snackbar('Erreur de localisation : $message');
    }
  }

  /// Centre la caméra sur l'enveloppe des obs visibles (filtres appliqués).
  /// Utile pour "Voir toutes mes obs" en un tap.
  Future<void> _fitVisibleBounds() async {
    final map = _map;
    if (map == null) return;
    final items =
        ref.read(allObservationsForMapProvider).asData?.value ?? const [];
    final filtered = items.where(_matchesFilters).toList();
    if (filtered.isEmpty) {
      _snackbar('Aucune observation à recadrer.');
      return;
    }
    if (filtered.length == 1) {
      final i = filtered.first;
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(i.obs.longitude, i.obs.latitude)),
          zoom: 13,
        ),
        MapAnimationOptions(duration: 600),
      );
      return;
    }
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final i in filtered) {
      if (i.obs.latitude < minLat) minLat = i.obs.latitude;
      if (i.obs.latitude > maxLat) maxLat = i.obs.latitude;
      if (i.obs.longitude < minLng) minLng = i.obs.longitude;
      if (i.obs.longitude > maxLng) maxLng = i.obs.longitude;
    }
    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 90, left: 40, bottom: 110, right: 40),
      null,
      null,
      null,
      null,
    );
    await map.flyTo(camera, MapAnimationOptions(duration: 600));
  }

  Future<void> _cycleStyle() async {
    const cycle = [
      MapboxStyles.OUTDOORS,
      MapboxStyles.SATELLITE_STREETS,
      MapboxStyles.STANDARD,
    ];
    final idx = cycle.indexOf(_styleUri);
    final next = cycle[(idx + 1) % cycle.length];
    setState(() => _styleUri = next);
    await _map?.loadStyleURI(next);
    // _onStyleLoaded sera rappelé automatiquement → re-attache source + layers.
  }

  void _snackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------
  // Filtres
  // -------------------------------------------------------------

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

  bool get _hasActiveFilter =>
      _categoryFilter != null ||
      _rarityFilter != null ||
      _observerFilter != null;

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _rarityFilter = null;
      _observerFilter = null;
    });
    _refreshSource();
  }

  void _setCategoryFilter(String? id) {
    setState(() => _categoryFilter = id);
    _refreshSource();
  }

  void _setRarityFilter(Rarity? r) {
    setState(() => _rarityFilter = r);
    _refreshSource();
  }

  void _setObserverFilter(String? id) {
    setState(() => _observerFilter = id);
    _refreshSource();
  }

  // -------------------------------------------------------------
  // build
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Re-render à chaque changement du provider d'obs.
    ref.listen(allObservationsForMapProvider, (_, _) {
      _refreshSource();
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
            viewport: _initialViewport,
            styleUri: _styleUri,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: _FiltersBar(
              open: _filtersOpen,
              onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
              categoryFilter: _categoryFilter,
              rarityFilter: _rarityFilter,
              observerFilter: _observerFilter,
              visibleCount: visibleCount,
              totalCount: allItems.length,
              hasActiveFilter: _hasActiveFilter,
              onCategoryChanged: _setCategoryFilter,
              onRarityChanged: _setRarityFilter,
              onObserverChanged: _setObserverFilter,
              onClearAll: _clearFilters,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _FloatBtn(
                  icon: Icons.zoom_out_map,
                  tooltip: 'Voir toutes mes obs',
                  onTap: _fitVisibleBounds,
                ),
                const SizedBox(height: 8),
                _FloatBtn(
                  icon: Icons.layers_outlined,
                  tooltip: 'Style de carte',
                  onTap: _cycleStyle,
                ),
                const SizedBox(height: 8),
                _FloatBtn(
                  icon: Icons.my_location,
                  tooltip: 'Ma position',
                  onTap: _centerOnUser,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Boutons flottants (carte)
// =============================================================

class _FloatBtn extends StatelessWidget {
  const _FloatBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: surfaceBase,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: forestGreen, size: 22),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// FiltersBar — collapsible
// =============================================================

class _FiltersBar extends ConsumerWidget {
  const _FiltersBar({
    required this.open,
    required this.onToggle,
    required this.categoryFilter,
    required this.rarityFilter,
    required this.observerFilter,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilter,
    required this.onCategoryChanged,
    required this.onRarityChanged,
    required this.onObserverChanged,
    required this.onClearAll,
  });

  final bool open;
  final VoidCallback onToggle;
  final String? categoryFilter;
  final Rarity? rarityFilter;
  final String? observerFilter;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<Rarity?> onRarityChanged;
  final ValueChanged<String?> onObserverChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBase.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header — toujours visible. Tap pour expand/collapse.
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      hasActiveFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                      size: 16,
                      color: hasActiveFilter ? terracotta : forestGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filtres',
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: forestGreen,
                      ),
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: terracotta,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Text(
                      '$visibleCount / $totalCount obs.',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (hasActiveFilter && !open)
                      TextButton(
                        onPressed: onClearAll,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Tout effacer',
                          style: GoogleFonts.karla(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: terracotta,
                          ),
                        ),
                      ),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: forestGreen,
                    ),
                  ],
                ),
              ),
            ),
            // Corps collapsible
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open
                  ? _FiltersBody(
                      categoryFilter: categoryFilter,
                      rarityFilter: rarityFilter,
                      observerFilter: observerFilter,
                      onCategoryChanged: onCategoryChanged,
                      onRarityChanged: onRarityChanged,
                      onObserverChanged: onObserverChanged,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBody extends ConsumerWidget {
  const _FiltersBody({
    required this.categoryFilter,
    required this.rarityFilter,
    required this.observerFilter,
    required this.onCategoryChanged,
    required this.onRarityChanged,
    required this.onObserverChanged,
  });

  final String? categoryFilter;
  final Rarity? rarityFilter;
  final String? observerFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<Rarity?> onRarityChanged;
  final ValueChanged<String?> onObserverChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_categoriesProvider);
    final observersAsync = ref.watch(observersProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
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

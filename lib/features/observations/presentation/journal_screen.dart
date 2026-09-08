import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  /// Flag pour ne recadrer automatiquement qu'au 1er chargement non-vide.
  /// Sans ça, chaque ajout d'obs ré-écraserait le pan/zoom manuel de l'user.
  bool _didInitialFit = false;

  /// Cache du dernier payload GeoJSON poussé dans la source — permet de
  /// skip un `setStyleSourceProperty` si les données n'ont pas changé.
  /// Utile au boot : `_onStyleLoaded` peut fire 2× sur Android + `ref.listen`
  /// peut re-notifier sur émissions dupliquées de `allObservationsForMapProvider`
  /// (le provider dépend de `currentAuthUserProvider` qui peut émettre 2×
  /// au démarrage). Sans dédup, chaque push re-render tous les layers → flicker.
  String? _lastPushedGeoJson;

  /// True quand le style Mapbox est chargé, les layers ajoutés et le 1er
  /// push de données terminé — à partir de là on peut fade l'overlay de
  /// masquage. Avant, on cache tout (l'user voit un fond crème stable au
  /// lieu du chargement chaotique des tiles + des ajouts de layers).
  bool _mapReady = false;

  /// Obs mise en avant après un tap depuis la fiche espèce. Reste affichée en
  /// callout en bas de l'écran jusqu'à ce que l'user la ferme (pas d'auto-
  /// dismiss — utile pour se réorienter dans les alentours à son rythme).
  ObservationOnMap? _focusedItem;

  static const _sourceId = 'obs';
  static const _layerClusters = 'obs-clusters';
  static const _layerClusterCount = 'obs-cluster-count';
  static const _layerPoint = 'obs-point';

  /// Layer du halo doré autour du point focusé — sur la source PARTAGÉE
  /// (clustered). Combiné à `['!', ['has', 'point_count']]` dans son filtre,
  /// il ne rend QUE quand le point est individuel (non-clusterisé), pareil
  /// que _layerPoint. Résultat : le halo disparaît/réapparaît en même temps
  /// que le point cible, sans seuil zoom hardcodé.
  static const _layerFocusHalo = 'obs-focus-halo';

  /// Sentinelle utilisée dans le filtre du halo quand aucune obs n'est
  /// focusée — aucune obs n'aura jamais cet id, donc le layer rend rien.
  static const _noMatchObsId = '__none__';

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

    // Nettoyage UNIQUEMENT si on détecte les vestiges d'une version
    // antérieure : source dédiée 'obs-focus' présente = ancien layer
    // (avec source dédiée + minZoom hardcodé). On remove les 2 pour
    // re-créer proprement en dessous.
    //
    // Sans ce garde, `_onStyleLoaded` remove+re-add le halo à chaque fire
    // (Android fire 2× au boot cf. comment plus haut, plus à chaque switch
    // de style de carte) → flicker visible sur le halo entre remove et add.
    try {
      if (await map.style.styleSourceExists('obs-focus')) {
        if (await map.style.styleLayerExists(_layerFocusHalo)) {
          await map.style.removeStyleLayer(_layerFocusHalo);
        }
        await map.style.removeStyleSource('obs-focus');
      }
    } catch (_) {}

    // Layer du halo focus — sur la source PARTAGÉE, ajouté AVANT le point
    // pour rendre DESSOUS (le point coloré rareté reste au-dessus, lisible).
    // Filtre initial = `!point_count && obs_id == sentinel` : ne matche rien
    // par défaut. Update via setStyleLayerProperty quand une obs est focusée.
    // Comme le filtre inclut `!has point_count`, le halo suit exactement la
    // visibilité du _layerPoint (masqué en cluster, visible en individuel).
    // Idempotent : si le layer existe déjà (2ème fire de _onStyleLoaded), skip.
    if (!await map.style.styleLayerExists(_layerFocusHalo)) {
      await map.style.addLayer(CircleLayer(
        id: _layerFocusHalo,
        sourceId: _sourceId,
        filter: [
          'all',
          ['!', ['has', 'point_count']],
          ['==', ['get', 'obs_id'], _noMatchObsId],
        ],
        // Gold — vocabulaire "récompense/focus" de l'app.
        circleRadius: 22,
        circleColor: 0xFFC49120,
        circleOpacity: 0.25,
        circleStrokeColor: 0xFFC49120,
        circleStrokeWidth: 3,
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

    // Style + layers OK, data poussée → on peut lever le voile de masquage.
    // Petit délai pour laisser Mapbox terminer le rendu de ses tiles avant
    // le fade — sinon on révèle une carte encore en train de se dessiner
    // (les clignotements résiduels au boot venaient de là). 500 ms est un
    // sweet spot : imperceptible en usage, laisse le moteur GL se stabiliser.
    // setState idempotent : safe même si _onStyleLoaded fire 2× sur Android.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted && !_mapReady) {
      setState(() => _mapReady = true);
    }
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

    // Skip si identique à la dernière push — évite le re-render inutile
    // des layers (source d'un flicker visible au boot avec appels redondants).
    if (geoJson == _lastPushedGeoJson) return;
    _lastPushedGeoJson = geoJson;

    await map.style.setStyleSourceProperty(_sourceId, 'data', geoJson);

    // Au tout 1er render non-vide on recentre la caméra sur l'enveloppe des
    // obs pour que l'user voie ses points directement (vs la vue par défaut
    // sur Compiègne). Pas d'animation : on snap, c'est l'état initial.
    if (!_didInitialFit && filtered.isNotEmpty) {
      _didInitialFit = true;
      await _fitVisibleBounds(animated: false);
    }

    // Un focus a pu être posé par la fiche espèce AVANT que la map soit
    // prête / les obs chargées — on le consomme dès qu'on peut.
    await _consumeFocusedObservationIfAny();
  }

  /// Si [focusedObservationIdProvider] est set et que l'obs correspondante
  /// est chargée, on flyTo dessus et on affiche un callout persistant en bas
  /// de l'écran (pas de sheet — le user a déjà vu le détail sur la fiche
  /// espèce, ré-ouvrir serait redondant). Reset le provider en one-shot.
  Future<void> _consumeFocusedObservationIfAny() async {
    final map = _map;
    if (map == null || !mounted) return;
    final id = ref.read(focusedObservationIdProvider);
    if (id == null) return;
    final item = _byObsId[id];
    if (item == null) return; // Obs pas encore dans l'index → réessai plus tard.

    ref.read(focusedObservationIdProvider.notifier).state = null;

    await map.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(item.obs.longitude, item.obs.latitude),
        ),
        // Zoom 15 (vs clusterMaxZoom=14) pour garantir que l'obs est
        // dé-clusterisée et que le halo peut la cibler individuellement.
        zoom: 15,
      ),
      MapAnimationOptions(duration: 500),
    );
    if (!mounted) return;
    setState(() => _focusedItem = item);
    await _syncFocusHalo();
  }

  /// Met à jour le filtre du layer halo pour cibler l'obs [_focusedItem],
  /// ou la sentinelle "aucune" si null. Le filtre `!point_count` reste
  /// toujours actif → le halo suit naturellement la visibilité du point
  /// (masqué en cluster, visible en individuel, sans zoom hardcodé).
  Future<void> _syncFocusHalo() async {
    final map = _map;
    if (map == null) return;
    final targetId = _focusedItem?.obs.id ?? _noMatchObsId;
    final filter = [
      'all',
      ['!', ['has', 'point_count']],
      ['==', ['get', 'obs_id'], targetId],
    ];
    try {
      await map.style.setStyleLayerProperty(
        _layerFocusHalo,
        'filter',
        jsonEncode(filter),
      );
    } catch (_) {
      // Silent — layer pas prêt (rare, avant _onStyleLoaded).
    }
  }

  /// Ouvre le sheet de détail pour l'obs mise en avant. Appelé depuis la
  /// callout — la callout reste visible en dessous du sheet, ce qui permet
  /// de refermer le sheet et retrouver la carte centrée sans perdre le contexte.
  Future<void> _openFocusedDetail(ObservationOnMap item) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ObservationDetailSheet(item: item),
    );
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
        _openPointDetail(feature);
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

  void _openPointDetail(Map<Object?, Object?> feature) {
    final props = (feature['properties'] as Map?)?.cast<String, Object?>();
    final obsId = props?['obs_id'] as String?;
    if (obsId == null) return;
    final item = _byObsId[obsId];
    if (item == null || !mounted) return;
    // Comportement uniforme quel que soit le point d'entrée (tap direct sur
    // un point OU arrivée depuis la fiche espèce) : on affiche la callout +
    // le halo, et l'user tape la callout pour ouvrir le sheet. Évite le
    // "double effet" tap = ouvre modal + laisse le focus, où l'user perd
    // la carte sous les yeux dès qu'il touche un point.
    setState(() => _focusedItem = item);
    unawaited(_syncFocusHalo());
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
  /// Utile pour le bouton "Voir toutes mes obs" et pour le 1er fit automatique
  /// au chargement de la carte. [animated] = true par défaut pour les actions
  /// utilisateur ; false pour le fit initial qui doit snap directement.
  Future<void> _fitVisibleBounds({bool animated = true}) async {
    final map = _map;
    if (map == null) return;
    final items =
        ref.read(allObservationsForMapProvider).asData?.value ?? const [];
    final filtered = items.where(_matchesFilters).toList();
    if (filtered.isEmpty) {
      if (animated) _snackbar('Aucune observation à recadrer.');
      return;
    }

    Future<void> apply(CameraOptions options) async {
      if (animated) {
        await map.flyTo(options, MapAnimationOptions(duration: 600));
      } else {
        await map.setCamera(options);
      }
    }

    if (filtered.length == 1) {
      final i = filtered.first;
      await apply(CameraOptions(
        center: Point(coordinates: Position(i.obs.longitude, i.obs.latitude)),
        zoom: 13,
      ));
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
    await apply(camera);
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
    return true;
  }

  bool get _hasActiveFilter =>
      _categoryFilter != null || _rarityFilter != null;

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _rarityFilter = null;
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

  // -------------------------------------------------------------
  // build
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Re-render à chaque changement du provider d'obs.
    ref.listen(allObservationsForMapProvider, (_, _) {
      _refreshSource();
    });
    // Focus depuis la fiche espèce → on tente immédiatement (utile si l'user
    // revient sur le carnet alors qu'il est déjà mount et que la map est
    // prête). Sinon _refreshSource s'en occupera au prochain refresh.
    ref.listen<String?>(focusedObservationIdProvider, (_, next) {
      if (next != null) _consumeFocusedObservationIfAny();
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
          // Voile de masquage au boot — cache les micro-flashs de chargement
          // Mapbox (tiles CDN, ajouts de layers en cascade, 2 fires
          // possibles de _onStyleLoaded). Fade out une fois _mapReady bascule
          // après le 1er _refreshSource complet. IgnorePointer pour ne pas
          // bloquer les gestures une fois transparent.
          IgnorePointer(
            ignoring: _mapReady,
            child: AnimatedOpacity(
              opacity: _mapReady ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: Container(
                color: surfaceBase,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Longue-vue statique — évoque le naturaliste qui
                    // scrute l'horizon, cohérent avec la DA naturaliste.
                    const Text('🔭', style: TextStyle(fontSize: 84)),
                    const SizedBox(height: 24),
                    // Shimmer terracotta sur le label pour marquer le "je
                    // travaille" sans avoir besoin d'un spinner en plus.
                    Text(
                      'CHARGEMENT DE LA CARTE…',
                      style: GoogleFonts.karla(
                        fontSize: 15,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          duration: const Duration(milliseconds: 1600),
                          color: terracotta.withValues(alpha: 0.6),
                        ),
                    const SizedBox(height: 20),
                    // Trace d'empreintes qui se posent une à une, comme un
                    // animal qui passe. Chaque patte est décalée + inclinée
                    // pour simuler une vraie foulée (gauche/droite/gauche…).
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _PawPrint(delayMs: 0, tiltDeg: -0.15),
                        SizedBox(width: 10),
                        _PawPrint(delayMs: 300, tiltDeg: 0.15),
                        SizedBox(width: 10),
                        _PawPrint(delayMs: 600, tiltDeg: -0.15),
                        SizedBox(width: 10),
                        _PawPrint(delayMs: 900, tiltDeg: 0.15),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Halo natif via CircleAnnotationManager — le rendu se fait côté
          // GL natif Mapbox, suit la carte automatiquement sans aucun bridge
          // Dart pendant les pans/zooms.
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: _FiltersBar(
              open: _filtersOpen,
              onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
              categoryFilter: _categoryFilter,
              rarityFilter: _rarityFilter,
              visibleCount: visibleCount,
              totalCount: allItems.length,
              hasActiveFilter: _hasActiveFilter,
              onCategoryChanged: _setCategoryFilter,
              onRarityChanged: _setRarityFilter,
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
          // Callout "cette obs" — collée en bas pour ne couvrir la carte
          // qu'au minimum. Marge droite pour laisser respirer les 3 boutons
          // flottants. Tap sur le corps → rouvre le sheet de détail. Le × à
          // droite est la seule action qui masque la callout.
          if (_focusedItem != null)
            Positioned(
              left: 12,
              right: 72,
              bottom: 16,
              child: _FocusedObsCallout(
                item: _focusedItem!,
                onOpen: () => _openFocusedDetail(_focusedItem!),
                onClose: () {
                  setState(() => _focusedItem = null);
                  // Retire l'annotation halo — asynchrone mais rapide,
                  // pas besoin d'await ici (setState suffit pour la callout).
                  unawaited(_syncFocusHalo());
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Bandeau flottant qui rappelle à l'user quelle obs est actuellement mise
/// en avant sur la carte (arrivée depuis la fiche espèce).
///
/// Deux zones tactiles distinctes :
///   - corps (icône + textes)         → rouvre le sheet de détail
///   - bouton × (droite)              → ferme la callout (seule sortie)
///
/// Callout basse : nom d'espèce + CTA insistant "OUVRIR L'OBSERVATION →".
/// Deux zones tactiles : corps (ouvre le sheet) et × (ferme la callout).
/// Choix UX : le tap "body" ne ferme pas — sinon l'user qui veut ouvrir se
/// coince à la fermer par erreur. On force l'action explicite via ×.
class _FocusedObsCallout extends StatelessWidget {
  const _FocusedObsCallout({
    required this.item,
    required this.onOpen,
    required this.onClose,
  });

  final ObservationOnMap item;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final species = item.species;
    return Material(
      color: surfaceBase,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: forestGreen, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: terracotta, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        // AnimatedSwitcher : quand l'user tape un autre
                        // point, le contenu (nom d'espèce + CTA) fait un
                        // fade + slide horizontal court, donnant un vrai
                        // signal "ça a changé" au lieu d'un swap muet.
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.12, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ...previous,
                              ?current,
                            ],
                          ),
                          child: Column(
                            // Key = obs.id : change de key = AnimatedSwitcher
                            // détecte un nouveau child et anime la transition.
                            key: ValueKey(item.obs.id),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                species?.commonName ?? 'Observation',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: forestGreen,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "OUVRIR L'OBSERVATION",
                                    style: GoogleFonts.karla(
                                      fontSize: 10.5,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.bold,
                                      color: terracotta,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Chevron avec nudge horizontal en boucle —
                                  // capte le regard vers l'action sans être
                                  // agressif (700ms aller-retour, easeInOut).
                                  const Icon(
                                    Icons.arrow_forward,
                                    size: 14,
                                    color: terracotta,
                                  )
                                      .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true))
                                      .moveX(
                                        begin: 0,
                                        end: 4,
                                        duration: const Duration(
                                            milliseconds: 700),
                                        curve: Curves.easeInOut,
                                      ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: const Color(0xFFE8E0CE),
            ),
            InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
              onTap: onClose,
              child: const SizedBox(
                width: 44,
                height: 60,
                child: Icon(Icons.close, size: 20, color: textMuted),
              ),
            ),
          ],
        ),
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
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilter,
    required this.onCategoryChanged,
    required this.onRarityChanged,
    required this.onClearAll,
  });

  final bool open;
  final VoidCallback onToggle;
  final String? categoryFilter;
  final Rarity? rarityFilter;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<Rarity?> onRarityChanged;
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
                      onCategoryChanged: onCategoryChanged,
                      onRarityChanged: onRarityChanged,
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
    required this.onCategoryChanged,
    required this.onRarityChanged,
  });

  final String? categoryFilter;
  final Rarity? rarityFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<Rarity?> onRarityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_categoriesProvider);
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

/// Empreinte 🐾 qui apparaît (fade + léger scale) avec un délai initial et
/// une inclinaison, pour simuler une foulée quand on en aligne plusieurs.
///
/// Le cycle complet dure ~3 s : apparition en cascade puis reset — comme si
/// un animal traversait la piste devant nous.
class _PawPrint extends StatelessWidget {
  const _PawPrint({required this.delayMs, required this.tiltDeg});

  final int delayMs;

  /// Rotation en tours (unité de flutter_animate : 1.0 = 360°).
  /// Valeurs typiques : -0.15 / +0.15 pour évoquer patte gauche/droite.
  final double tiltDeg;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
          angle: tiltDeg * 6.2831853, // tiltDeg tours → radians
          child: Text(
            '🐾',
            style: TextStyle(
              fontSize: 32,
              color: forestGreen.withValues(alpha: 0.85),
            ),
          ),
        )
        .animate(
          onPlay: (c) => c.repeat(period: const Duration(milliseconds: 3200)),
          delay: Duration(milliseconds: delayMs),
        )
        .fadeIn(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        )
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        )
        .then(delay: const Duration(milliseconds: 1100))
        .fadeOut(duration: const Duration(milliseconds: 400));
  }
}


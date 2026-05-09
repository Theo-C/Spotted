import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/theme.dart';
import '../../../shared/models/rarity.dart';
import '../data/observations_for_map_provider.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  CircleAnnotationManager? _circleManager;

  Future<void> _onMapCreated(MapboxMap map) async {
    _circleManager = await map.annotations.createCircleAnnotationManager();
    await _renderAnnotations();
  }

  /// Recharge tous les markers depuis le provider. Idempotent — on supprime
  /// d'abord les annotations existantes pour éviter les doublons.
  Future<void> _renderAnnotations() async {
    final manager = _circleManager;
    if (manager == null) return;
    final asyncItems = ref.read(allObservationsForMapProvider);
    final items = asyncItems.asData?.value;
    if (items == null) return;

    await manager.deleteAll();
    for (final item in items) {
      final colorInt = _rarityColorInt(item.rarity);
      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(item.obs.longitude, item.obs.latitude),
          ),
          circleRadius: 8,
          circleColor: colorInt,
          circleStrokeWidth: 2,
          circleStrokeColor: 0xFFFAF6EC, // surfaceBase
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    // Réagit aux changements de données : recharger les markers quand des
    // obs sont créées/supprimées (via invalidate du provider après submit).
    ref.listen(allObservationsForMapProvider, (_, _) {
      _renderAnnotations();
    });

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
      body: MapWidget(
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(2.82, 49.41)),
          zoom: 9.0,
        ),
        styleUri: MapboxStyles.OUTDOORS,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}

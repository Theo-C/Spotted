import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

  /// Mapping annotation ID → observation, pour résoudre le tap.
  final Map<String, ObservationOnMap> _byAnnotationId = {};

  Future<void> _onMapCreated(MapboxMap map) async {
    _circleManager = await map.annotations.createCircleAnnotationManager();
    _circleManager!
        .addOnCircleAnnotationClickListener(_AnnotationClickListener(this));
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
    _byAnnotationId.clear();
    for (final item in items) {
      final colorInt = _rarityColorInt(item.rarity);
      final annotation = await manager.create(
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
      _byAnnotationId[annotation.id] = item;
    }
  }

  void _handleAnnotationTap(CircleAnnotation annotation) {
    final item = _byAnnotationId[annotation.id];
    if (item == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ObservationDetailSheet(item: item),
    );
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

class _AnnotationClickListener extends OnCircleAnnotationClickListener {
  _AnnotationClickListener(this.parent);
  final _JournalScreenState parent;

  @override
  void onCircleAnnotationClick(CircleAnnotation annotation) {
    parent._handleAnnotationTap(annotation);
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
            // Drag handle
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
                    label: _rarityLabel(rarity),
                    color: _rarityColor(rarity),
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

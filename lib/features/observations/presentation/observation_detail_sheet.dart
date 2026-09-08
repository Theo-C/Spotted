import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../app/theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/fullscreen_photo_viewer.dart';
import '../../../shared/models/rarity.dart';
import '../../auth/data/auth_providers.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../territories/data/geocoding_service.dart';
import '../../territories/data/territory_progress_provider.dart';
import '../data/observation_repository.dart';
import '../data/observations_for_map_provider.dart';
import '../data/observed_species_provider.dart';

/// Bottom sheet de détail d'une observation, partagée entre le carnet
/// (tap sur un marker) et la fiche détail d'une espèce (tap sur une obs
/// dans la section "Mes observations").
///
/// Affiche photo + nom espèce + chips (date, points, rareté, 1ʳᵉ) +
/// coordonnées, plus deux actions :
///   - "Voir la fiche espèce" : navigue vers le détail de l'espèce
///     (utile depuis le carnet ; redondant depuis la fiche elle-même)
///   - "Supprimer cette observation" : uniquement si l'user est
///     propriétaire de l'obs (RLS 0007 garantissent l'enforcement BDD).
class ObservationDetailSheet extends ConsumerWidget {
  const ObservationDetailSheet({
    super.key,
    required this.item,
    this.showOpenSpeciesButton = true,
  });

  final ObservationOnMap item;

  /// Si on est déjà sur la fiche détail de l'espèce (tap d'une obs depuis
  /// "Mes observations"), masque ce bouton — sinon redondant.
  final bool showOpenSpeciesButton;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceBase,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer cette observation ?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
        content: Text(
          'Tu perdras les ${item.obs.pointsEarned} points associés et le marqueur disparaîtra du carnet. Action irréversible.',
          style: GoogleFonts.karla(fontSize: 13, color: textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Annuler',
              style: GoogleFonts.karla(color: textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: terracotta),
            child: Text(
              'Supprimer',
              style: GoogleFonts.karla(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(observationRepositoryProvider).delete(item.obs.id);
      // Reset le focus AVANT les invalidates — sinon JournalScreen garderait
      // un obs_id qui n'existe plus en base et son `_byObsId[id]` retournerait
      // null au prochain consume, sans crash mais avec halo silencieusement
      // cassé jusqu'à la prochaine sélection.
      ref.read(focusedObservationIdProvider.notifier).state = null;
      ref.invalidate(allObservationsForMapProvider);
      ref.invalidate(observedSpeciesIdsInZoneProvider);
      ref.invalidate(categoriesWithProgressProvider);
      ref.invalidate(zoneProgressProvider);
      ref.invalidate(accountTotalPointsProvider);
      ref.invalidate(accountLevelProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de suppression : $e')),
        );
      }
    }
  }

  void _openSpeciesDetail(BuildContext context) {
    final categoryId = item.species?.categoryId;
    final zoneId = item.obs.zoneId;
    if (categoryId == null || zoneId == null) return;
    Navigator.of(context).pop();
    context.push(
      '/territory/$zoneId/category/$categoryId/species/${item.obs.speciesId}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = item.species;
    final rarity = item.rarity;
    final currentUserId = ref.watch(currentAuthUserProvider)?.id;
    final isOwner = currentUserId != null && item.obs.userId == currentUserId;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
              // Tap → fullscreen zoomable — pratique pour examiner un détail
              // du plumage / pelage sans avoir à quitter le sheet.
              GestureDetector(
                onTap: () =>
                    openFullscreenPhoto(context, item.obs.photoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: CachedNetworkImage(
                      imageUrl: item.obs.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: surfaceMuted),
                      errorWidget: (_, _, _) => Container(
                        color: surfaceMuted,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined,
                            color: textMuted, size: 32),
                      ),
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
                  label: DateFormatter.full(item.obs.observedAt),
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
                // Défi du jour — obs validée le jour où c'était l'espèce du
                // tirage → bonus x2 appliqué à pointsEarned au moment de
                // l'INSERT (cf. observationPoints).
                if (item.obs.wasDailySpecies)
                  _Chip(
                    icon: Icons.stars,
                    label: 'Défi du jour',
                    color: gold,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _MiniLocationMap(
              lat: item.obs.latitude,
              lng: item.obs.longitude,
              onTap: () {
                // Signale l'obs à focus, ferme le sheet, puis switch sur
                // l'onglet Carnet — le JournalScreen consomme le provider
                // dès qu'il est prêt (map + obs chargées) et se centre dessus.
                ref
                    .read(focusedObservationIdProvider.notifier)
                    .state = item.obs.id;
                Navigator.of(context).pop();
                context.go('/map');
              },
            ),
            const SizedBox(height: 8),
            _PlaceLine(
              lat: item.obs.latitude,
              lng: item.obs.longitude,
            ),
            if (showOpenSpeciesButton && species != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openSpeciesDetail(context),
                icon: const Icon(Icons.pets, size: 18),
                label: Text(
                  "Voir la fiche d'espèce",
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: forestGreen,
                  foregroundColor: surfaceBase,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            if (isOwner) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _confirmAndDelete(context, ref),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: terracotta),
                label: Text(
                  'Supprimer cette observation',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: terracotta,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: terracotta, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
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

/// Aperçu Mapbox 140 px centré sur l'observation. Non-interactif (les
/// gestures Flutter reprennent le dessus via EagerGestureRecognizer sur le
/// parent scrollable — la carte reste statique). Sert de visualisation
/// rapide "où c'était" sans ouvrir le carnet complet.
class _MiniLocationMap extends StatefulWidget {
  const _MiniLocationMap({
    required this.lat,
    required this.lng,
    this.onTap,
  });

  final double lat;
  final double lng;

  /// Si non null, un overlay tactile transparent est superposé et intercepte
  /// tous les tap (les gestures Mapbox restent désactivées de toute façon).
  /// Un badge "Ouvrir dans le carnet" apparaît en overlay pour l'affordance.
  final VoidCallback? onTap;

  @override
  State<_MiniLocationMap> createState() => _MiniLocationMapState();
}

class _MiniLocationMapState extends State<_MiniLocationMap> {
  late final CameraViewportState _viewport;

  @override
  void initState() {
    super.initState();
    _viewport = CameraViewportState(
      center: Point(coordinates: Position(widget.lng, widget.lat)),
      zoom: 13,
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(CompassSettings(enabled: false));
    await map.attribution
        .updateSettings(AttributionSettings(enabled: false));
    await map.logo.updateSettings(LogoSettings(enabled: false));
    // Désactive toutes les gestures : c'est un aperçu, on ne veut pas
    // que l'user pan/zoome (utiliserait le carnet plein écran pour ça).
    await map.gestures.updateSettings(GesturesSettings(
      rotateEnabled: false,
      scrollEnabled: false,
      pinchToZoomEnabled: false,
      doubleTapToZoomInEnabled: false,
      doubleTouchToZoomOutEnabled: false,
      quickZoomEnabled: false,
      pitchEnabled: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 140,
        child: Stack(
          children: [
            MapWidget(
              viewport: _viewport,
              styleUri: MapboxStyles.OUTDOORS,
              onMapCreated: _onMapCreated,
              // On absorbe les gestures Flutter — sinon la bottom sheet ne
              // pourrait plus être drag-fermée depuis la zone de la carte.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  VerticalDragGestureRecognizer.new,
                ),
              },
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Icon(
                  Icons.location_on,
                  color: terracotta,
                  size: 32,
                ),
              ),
            ),
            if (widget.onTap != null) ...[
              // Overlay tactile plein — comme les gestures Mapbox sont off,
              // c'est un simple InkWell qui capture le tap.
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: widget.onTap),
                ),
              ),
              // Badge d'affordance : indique clairement que la carte est
              // cliquable et où le tap mène.
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceBase.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: forestGreen, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 12,
                        color: forestGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CARNET',
                        style: GoogleFonts.karla(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                          color: forestGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Affiche le lieu de l'observation via reverse-geocoding Mapbox.
/// Tant que le geocoding est en cours ou si la requête échoue, retombe
/// sur les coords pour ne jamais montrer un vide visuel. Le provider
/// est cached par couple (lat, lng) donc une obs ouverte 2 fois ne
/// rappelle pas l'API.
class _PlaceLine extends ConsumerWidget {
  const _PlaceLine({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geocodingAsync = ref.watch(
      reverseGeocodingProvider((lat: lat, lng: lng)),
    );
    final placeText = geocodingAsync.asData?.value?.displayName ??
        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    return Row(
      children: [
        const Icon(Icons.place_outlined, size: 14, color: terracotta),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            placeText,
            style: GoogleFonts.karla(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ),
      ],
    );
  }
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


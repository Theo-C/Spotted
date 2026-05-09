import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/env.dart';

/// Résultat d'un reverse-geocoding Mapbox.
/// [region] est le champ critique pour la détection territoire :
/// on le compare au nom de zone curée (ex: "Oise") avant de valider une obs.
class GeocodingResult {
  const GeocodingResult({this.place, this.region, this.country});

  /// Commune ou ville (ex: "Soissons", "Compiègne").
  final String? place;

  /// Département (Mapbox renvoie le département français au place_type 'region').
  final String? region;

  /// Pays (ex: "France").
  final String? country;

  /// Format compact pour affichage : "Compiègne, Oise" ou juste "Oise" si pas de commune.
  String? get displayName {
    final parts = <String>[];
    if (place != null) parts.add(place!);
    if (region != null) parts.add(region!);
    return parts.isEmpty ? null : parts.join(', ');
  }
}

class GeocodingService {
  GeocodingService(this._dio);

  final Dio _dio;

  /// Reverse-geocode lat/lng → commune + département via Mapbox Places API.
  /// Renvoie null en cas d'erreur réseau ou si pas de résultats.
  ///
  /// Note implémentation : on ne filtre PAS sur `types=place,region,country`
  /// dans la query car Mapbox peut renvoyer des `place_type` différents selon
  /// les pays (ex: `district` en France pour le département). On récupère
  /// tout, on parse côté client.
  Future<GeocodingResult?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      // Mapbox reverse geocoding refuse limit > 1 sans `types`. On précise
      // donc tous les types qu'on consomme (country, region, district, place,
      // locality, postcode) et limit = nb de types.
      const types = 'country,region,district,place,locality,postcode';
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json',
        queryParameters: {
          'access_token': Env.mapboxAccessToken,
          'language': 'fr',
          'types': types,
          'limit': 6,
        },
      );
      final features = response.data?['features'] as List?;
      if (features == null) {
        debugPrint(
          '[geocoding] response has no features. Status=${response.statusCode}',
        );
        return null;
      }

      String? place;
      String? region;
      String? country;
      // On dump le pretty-print des place_types présents pour debug.
      final summary = <String>[];
      for (final f in features) {
        final m = f as Map<String, dynamic>;
        final placeType = (m['place_type'] as List?)?.cast<String>() ?? [];
        final text = (m['text_fr'] as String?) ?? (m['text'] as String?);
        summary.add('${placeType.join("|")}=$text');
        if (text == null) continue;
        // Place / commune
        if ((placeType.contains('place') || placeType.contains('locality')) &&
            place == null) {
          place = text;
        }
        // Région / département : selon Mapbox, le département français peut
        // arriver soit en `region` soit en `district`. On essaie les deux.
        if ((placeType.contains('district') ||
                placeType.contains('region')) &&
            region == null) {
          region = text;
        }
        if (placeType.contains('country') && country == null) {
          country = text;
        }
      }
      debugPrint(
        '[geocoding] ($lat,$lng) → features: ${summary.join(", ")} | parsed: place=$place region=$region country=$country',
      );
      return GeocodingResult(place: place, region: region, country: country);
    } on DioException catch (e) {
      debugPrint(
        '[geocoding] network error: ${e.message} (status=${e.response?.statusCode})',
      );
      return null;
    } catch (e) {
      debugPrint('[geocoding] parse error: $e');
      return null;
    }
  }
}

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(Dio());
});

/// Reverse-geocoding pour une paire (lat, lng).
/// Cached par paire de coordonnées (Riverpod family + équivalence sur record).
final reverseGeocodingProvider =
    FutureProvider.family<GeocodingResult?, ({double lat, double lng})>(
  (ref, coords) async {
    return ref
        .watch(geocodingServiceProvider)
        .reverseGeocode(lat: coords.lat, lng: coords.lng);
  },
);

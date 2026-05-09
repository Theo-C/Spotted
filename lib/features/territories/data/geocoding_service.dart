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

  /// Reverse-geocode lat/lng → commune + département via Mapbox Geocoding API v6.
  ///
  /// On utilise v6 (et pas v5 legacy qui retourne du 422 selon les paramètres).
  /// En v6, le 1er feature renvoie `properties.context` qui contient tous les
  /// niveaux administratifs d'un coup — pas besoin de boucler sur plusieurs.
  ///
  /// Doc : https://docs.mapbox.com/api/search/geocoding-v6/
  Future<GeocodingResult?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.mapbox.com/search/geocode/v6/reverse',
        queryParameters: {
          'longitude': lng,
          'latitude': lat,
          'access_token': Env.mapboxAccessToken,
          'language': 'fr',
          'limit': 1,
        },
      );
      final features = response.data?['features'] as List?;
      if (features == null || features.isEmpty) {
        debugPrint(
          '[geocoding] no features. Status=${response.statusCode}',
        );
        return null;
      }
      final feature = features.first as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>?;
      final ctx = props?['context'] as Map<String, dynamic>?;

      String? nameOf(String key) {
        final entry = ctx?[key] as Map<String, dynamic>?;
        return entry?['name'] as String?;
      }

      // Place / commune : on essaie place puis locality.
      final place = nameOf('place') ?? nameOf('locality');
      // Région / département : Mapbox renvoie le département français dans
      // `region` (ex: "Oise"), la région administrative dans `region` aussi
      // selon les pays. district = niveau intermédiaire. On essaie les deux.
      final region = nameOf('region') ?? nameOf('district');
      final country = nameOf('country');

      debugPrint(
        '[geocoding] ($lat,$lng) → place=$place region=$region country=$country (raw context keys: ${ctx?.keys.join(",")})',
      );
      return GeocodingResult(place: place, region: region, country: country);
    } on DioException catch (e) {
      debugPrint(
        '[geocoding] network error: ${e.message} (status=${e.response?.statusCode}) body=${e.response?.data}',
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Récupère la position courante de l'appareil. Gère permissions + état du GPS.
///
/// Le UX pattern : on demande la permission au moment où l'utilisateur en a
/// besoin (tap "ma position"), pas au lancement. Si l'user refuse, on lui
/// dit pourquoi via un retour explicite (état [LocationFetchResult]).
class LocationService {
  Future<LocationFetchResult> getCurrentPosition() async {
    // 1. Service GPS activé sur l'appareil ?
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationFetchResult.serviceDisabled();
    }
    // 2. Permission accordée ?
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationFetchResult.denied();
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationFetchResult.deniedForever();
    }
    // 3. Récupérer la position.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationFetchResult.success(
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      return LocationFetchResult.error(e.toString());
    }
  }
}

sealed class LocationFetchResult {
  const LocationFetchResult();

  const factory LocationFetchResult.success({
    required double lat,
    required double lng,
  }) = LocationSuccess;

  const factory LocationFetchResult.serviceDisabled() = LocationServiceDisabled;
  const factory LocationFetchResult.denied() = LocationDenied;
  const factory LocationFetchResult.deniedForever() = LocationDeniedForever;
  const factory LocationFetchResult.error(String message) = LocationError;
}

class LocationSuccess extends LocationFetchResult {
  const LocationSuccess({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

class LocationServiceDisabled extends LocationFetchResult {
  const LocationServiceDisabled();
}

class LocationDenied extends LocationFetchResult {
  const LocationDenied();
}

class LocationDeniedForever extends LocationFetchResult {
  const LocationDeniedForever();
}

class LocationError extends LocationFetchResult {
  const LocationError(this.message);
  final String message;
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

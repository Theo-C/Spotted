import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance locale des flags "tip déjà vu / onboarding fait".
/// Pas de besoin de sync cloud — c'est de l'UX local.
class OnboardingService {
  static const _kCameraGpsTipSeen = 'tip_camera_gps_seen';

  Future<bool> hasSeenCameraGpsTip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCameraGpsTipSeen) ?? false;
  }

  Future<void> markCameraGpsTipSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCameraGpsTipSeen, true);
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

/// True tant que l'utilisateur n'a pas dismiss le tip "active la géoloc cam".
/// Permet de rebuild la Home quand on dismiss (via invalidate).
final cameraGpsTipVisibleProvider = FutureProvider<bool>((ref) async {
  final seen =
      await ref.watch(onboardingServiceProvider).hasSeenCameraGpsTip();
  return !seen;
});

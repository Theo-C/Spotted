import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// État d'onboarding persisté localement. Singleton car le router doit pouvoir
/// le watcher de façon synchrone (Listenable) — on pré-charge depuis
/// SharedPreferences au boot via [init] avant le runApp.
///
/// Pas de besoin de sync cloud — c'est de l'UX local par device.
class OnboardingService extends ChangeNotifier {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();

  static const _kOnboardingComplete = 'onboarding_complete_v1';

  bool _completed = false;
  bool _loaded = false;

  bool get completed => _completed;
  bool get loaded => _loaded;

  /// À appeler une fois au boot avant runApp pour pré-charger l'état.
  /// Sans ça le router ne sait pas s'il doit rediriger vers /onboarding.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _completed = prefs.getBool(_kOnboardingComplete) ?? false;
    _loaded = true;
    notifyListeners();
  }

  /// Marque l'onboarding comme terminé. Le router redirect notifie alors
  /// vers / (l'écran Home).
  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingComplete, true);
    _completed = true;
    notifyListeners();
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService.instance;
});

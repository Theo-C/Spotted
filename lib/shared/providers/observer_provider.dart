import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/data/user_repository.dart';
import '../models/app_user.dart';

/// ID de l'observateur courant — peut être différent du user connecté
/// (compte partagé Théo & Axelle). Initialisé sur le user connecté,
/// modifiable via [CurrentObserverNotifier.setObserver].
///
/// Pas persisté entre lancements de l'app : redémarrer l'app = retour
/// à l'observateur = user connecté.
final currentObserverIdProvider =
    NotifierProvider<CurrentObserverNotifier, String?>(
  CurrentObserverNotifier.new,
);

class CurrentObserverNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Réinitialise sur l'auth user à chaque changement d'auth.
    return ref.watch(currentAuthUserProvider)?.id;
  }

  /// Bascule l'observateur courant (Théo ↔ Axelle).
  void setObserver(String userId) {
    state = userId;
  }
}

/// Profil applicatif (AppUser) de l'observateur courant.
final currentObserverProvider = FutureProvider<AppUser?>((ref) async {
  final id = ref.watch(currentObserverIdProvider);
  if (id == null) return null;
  return ref.watch(userRepositoryProvider).getById(id);
});

/// Liste des 2 observateurs disponibles (Théo + Axelle), pour
/// alimenter le toggle UI.
final observersProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.watch(userRepositoryProvider).getAll();
});

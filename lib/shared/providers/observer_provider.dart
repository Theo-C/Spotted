import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_repository.dart';
import '../models/app_user.dart';

/// Liste des utilisateurs (Théo + Axelle), pour alimenter le filtre
/// "afficher les obs de…" sur la carte du carnet.
///
/// Avec le passage à 2 comptes auth dissociés (mai 2026), il n'y a plus de
/// notion d'« observateur courant à toggler » — l'observer est implicitement
/// le user authentifié (cf. currentAuthUserProvider). Ce fichier n'expose
/// donc plus que la liste des users connus.
final observersProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.watch(userRepositoryProvider).getAll();
});

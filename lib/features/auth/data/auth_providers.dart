import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/app_user.dart';
import 'auth_repository.dart';
import 'user_repository.dart';

/// Stream des évènements d'authentification (login, logout, refresh).
/// Surveiller ce provider pour réagir aux changements de session.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// User Supabase Auth (null si pas connecté).
/// Recalculé à chaque émission de authStateChangesProvider.
final currentAuthUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).currentAuthUser;
});

/// Profil applicatif (AppUser) du user connecté — fait le lien
/// auth.users.id ↔ public.users.id.
/// Null si pas connecté ou si la ligne public.users n'existe pas encore.
final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  final authUser = ref.watch(currentAuthUserProvider);
  if (authUser == null) return null;
  return ref.watch(userRepositoryProvider).getById(authUser.id);
});

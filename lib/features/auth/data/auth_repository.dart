import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/supabase_client_provider.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Session courante (null si pas connecté).
  Session? get currentSession => _client.auth.currentSession;

  /// User Supabase Auth (null si pas connecté).
  /// À distinguer d'AppUser (notre profil applicatif dans public.users).
  User? get currentAuthUser => _client.auth.currentUser;

  /// Stream qui émet à chaque login / logout / refresh de token.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

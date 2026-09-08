import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/supabase_client_provider.dart';

/// Deep link vers lequel Supabase redirige après un magic link ou un
/// OAuth callback. Doit matcher l'intent-filter Android
/// (AndroidManifest.xml) ET les Redirect URLs configurées dans Supabase
/// Dashboard → Auth → URL Configuration.
const _deepLinkRedirect = 'io.spotted.app://auth-callback';

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

  /// Ouvre le flow OAuth Google. Sur mobile, Supabase délègue au navigateur
  /// externe (ou onglet Chrome Custom Tab), l'user consent, revient à l'app
  /// via le deep link `io.spotted.app://auth-callback`.
  ///
  /// Nécessite côté config :
  ///   - Supabase Dashboard → Auth → Providers → Google enabled
  ///   - Google Cloud OAuth 2.0 client ID + SHA-1 fingerprint de l'app
  ///   - Intent-filter dans AndroidManifest.xml
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _deepLinkRedirect,
    );
  }

  /// Envoie un magic link à l'email fourni. L'user reçoit un email avec
  /// un lien qui, tapé, ouvre l'app via le deep link et crée la session.
  /// Sign-up implicite : si l'email n'existe pas encore, Supabase crée le
  /// compte au moment du 1er tap du lien (auto-create trigger fait le reste).
  Future<void> signInWithMagicLink(String email) {
    return _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: _deepLinkRedirect,
    );
  }

  /// Password sign-in — conservé pour les comptes historiques créés
  /// manuellement avant l'ouverture au public. Ne devrait plus être exposé
  /// dans l'UI standard (les nouveaux users passent par Google / Magic Link).
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/app_user.dart';
import '../../../shared/providers/supabase_client_provider.dart';

class UserRepository {
  UserRepository(this._client);

  final SupabaseClient _client;

  /// Profil de l'utilisateur connecté. null si pas connecté
  /// ou si sa ligne `public.users` n'existe pas encore.
  Future<AppUser?> getCurrent() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    return getById(authUser.id);
  }

  Future<AppUser?> getById(String id) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return AppUser.fromJson(row);
  }

  /// Tous les profils (Théo + Axelle).
  Future<List<AppUser>> getAll() async {
    final rows = await _client.from('users').select();
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList();
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseClientProvider));
});

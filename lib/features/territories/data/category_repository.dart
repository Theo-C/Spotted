import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/category.dart';
import '../../../shared/providers/supabase_client_provider.dart';

class CategoryRepository {
  CategoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Category>> getAll() async {
    final rows = await _client
        .from('categories')
        .select()
        .order('sort_order');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList();
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});

/// Toutes les catégories du catalogue, cachées via `keepAlive` : le contenu
/// change extrêmement rarement (édition manuelle admin), autant éviter les
/// refetches à chaque navigation.
final allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.keepAlive();
  return ref.watch(categoryRepositoryProvider).getAll();
});

/// Lookup O(1) par id — pratique pour les widgets qui rendent des listes
/// d'items catégorisés (obs récentes, cartes de la Home, etc.). Évite le
/// pattern `list.firstWhere(id)` répété N fois par frame.
final categoriesByIdProvider =
    FutureProvider<Map<String, Category>>((ref) async {
  final list = await ref.watch(allCategoriesProvider.future);
  return {for (final c in list) c.id: c};
});

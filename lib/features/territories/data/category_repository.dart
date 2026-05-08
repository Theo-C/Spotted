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

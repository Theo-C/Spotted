import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import 'category_repository.dart';
import 'zone_repository.dart';

/// Zone Oise (60) — utilisée comme territoire de référence du MVP.
/// FutureProvider plutôt qu'une constante car l'UUID est généré par
/// Supabase (pas connu à la compilation).
final oiseZoneProvider = FutureProvider<Zone>((ref) async {
  final zones = await ref.watch(zoneRepositoryProvider).getAll();
  return zones.firstWhere((z) => z.shortCode == '60');
});

/// Progression par catégorie pour une zone donnée.
class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.observed,
    required this.total,
  });

  final Category category;
  final int observed;
  final int total;

  int get remaining => total - observed;
  double get fraction => total == 0 ? 0 : observed / total;
}

/// Liste des catégories enrichies de leur progression sur la zone donnée.
/// Compte partagé : toutes les obs (les 2 users), pas de filtre par observateur.
final categoriesWithProgressProvider =
    FutureProvider.family<List<CategoryProgress>, String>((ref, zoneId) async {
  final client = ref.watch(supabaseClientProvider);
  final categories = await ref.watch(categoryRepositoryProvider).getAll();

  // Total : species_zones de la zone, on récupère le category_id via jointure.
  final totalRows = await client
      .from('species_zones')
      .select('species_id, species!inner(category_id)')
      .eq('zone_id', zoneId);

  // Observed : observations de la zone, on récupère le category_id via jointure.
  final obsRows = await client
      .from('observations')
      .select('species_id, species!inner(category_id)')
      .eq('zone_id', zoneId);

  final totalByCategory = <String, int>{};
  for (final row in totalRows as List) {
    final categoryId = ((row as Map<String, dynamic>)['species']
        as Map<String, dynamic>)['category_id'] as String;
    totalByCategory[categoryId] = (totalByCategory[categoryId] ?? 0) + 1;
  }

  final observedByCategory = <String, Set<String>>{};
  for (final row in obsRows as List) {
    final m = row as Map<String, dynamic>;
    final speciesId = m['species_id'] as String;
    final categoryId =
        (m['species'] as Map<String, dynamic>)['category_id'] as String;
    observedByCategory.putIfAbsent(categoryId, () => {}).add(speciesId);
  }

  return categories
      .map(
        (c) => CategoryProgress(
          category: c,
          total: totalByCategory[c.id] ?? 0,
          observed: observedByCategory[c.id]?.length ?? 0,
        ),
      )
      .toList();
});

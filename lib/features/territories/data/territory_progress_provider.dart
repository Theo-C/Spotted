import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import 'category_repository.dart';
import 'zone_repository.dart';

/// Toutes les zones du pays courant (MVP : 60 Oise + 02 Aisne).
/// Source de vérité pour itérer les territoires sur la Home (vs hard-codé
/// avant). Quand on ajoutera la Somme, il suffira de l'insérer en BDD.
final allZonesProvider = FutureProvider<List<Zone>>((ref) async {
  final zones = await ref.watch(zoneRepositoryProvider).getAll();
  // Oise d'abord (DOMICILE), puis les autres. Tri stable sur shortCode.
  zones.sort((a, b) {
    if (a.shortCode == '60') return -1;
    if (b.shortCode == '60') return 1;
    return (a.shortCode ?? '').compareTo(b.shortCode ?? '');
  });
  return zones;
});

/// Zone par short_code (ex: '60' pour Oise, '02' pour Aisne).
/// FutureProvider.family plutôt qu'une constante car les UUIDs sont
/// générés par Supabase (pas connus à la compilation).
final zoneByShortCodeProvider =
    FutureProvider.family<Zone, String>((ref, shortCode) async {
  final zones = await ref.watch(zoneRepositoryProvider).getAll();
  return zones.firstWhere((z) => z.shortCode == shortCode);
});

/// Zone Oise (60) — kept for backward-compat. Prefer zoneByShortCodeProvider.
final oiseZoneProvider =
    FutureProvider<Zone>((ref) => ref.watch(zoneByShortCodeProvider('60').future));

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
/// Progression individuelle (modèle 2 comptes dissociés depuis 2026-05-10) :
/// chaque user voit sa propre complétion par catégorie.
final categoriesWithProgressProvider =
    FutureProvider.family<List<CategoryProgress>, String>((ref, zoneId) async {
  final userId = ref.watch(currentAuthUserProvider)?.id;
  final client = ref.watch(supabaseClientProvider);
  final categories = await ref.watch(categoryRepositoryProvider).getAll();

  // Total : species_zones de la zone, on récupère le category_id via jointure.
  // (Total commun aux deux users — c'est le catalogue curé de la zone.)
  final totalRows = await client
      .from('species_zones')
      .select('species_id, species!inner(category_id)')
      .eq('zone_id', zoneId);

  // Observed : observations de l'utilisateur courant sur la zone.
  // Sans userId (pas connecté), on retourne 0 observation côté UI.
  final obsRows = userId == null
      ? const <Map<String, dynamic>>[]
      : await client
          .from('observations')
          .select('species_id, species!inner(category_id)')
          .eq('zone_id', zoneId)
          .eq('user_id', userId);

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

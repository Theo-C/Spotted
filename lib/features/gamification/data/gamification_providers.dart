import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/supabase_client_provider.dart';
import '../domain/level.dart';

/// Total des points cumulés sur le compte partagé Théo + Axelle.
/// Somme des observations.points_earned, sans filtre user.
final accountTotalPointsProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.from('observations').select('points_earned');
  return (rows as List).fold<int>(
    0,
    (acc, e) => acc + ((e as Map<String, dynamic>)['points_earned'] as int),
  );
});

/// Niveau du compte (calculé depuis les points cumulés des deux observateurs).
final accountLevelProvider = FutureProvider<LevelInfo>((ref) async {
  final points = await ref.watch(accountTotalPointsProvider.future);
  return computeLevel(points);
});

/// Progression sur un territoire : nb d'espèces distinctes observées (par
/// le compte) / nb total d'espèces curées dans la zone.
class TerritoryProgress {
  const TerritoryProgress({required this.observed, required this.total});

  final int observed;
  final int total;

  int get remaining => total - observed;
  double get fraction => total == 0 ? 0 : observed / total;
}

/// Progression du compte sur la zone Oise (60).
/// Combine le total d'espèces curées et le nombre d'espèces distinctes
/// observées (peu importe l'observateur).
final oiseProgressProvider = FutureProvider<TerritoryProgress>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  // Récupère l'id de la zone Oise
  final zone = await client
      .from('zones')
      .select('id')
      .eq('short_code', '60')
      .single();
  final zoneId = zone['id'] as String;

  // Total : nb d'espèces curées sur Oise
  final totalRows =
      await client.from('species_zones').select('species_id').eq('zone_id', zoneId);
  final total = (totalRows as List).length;

  // Observed : nb d'espèces distinctes observées sur Oise (compte partagé)
  final obsRows =
      await client.from('observations').select('species_id').eq('zone_id', zoneId);
  final distinct = (obsRows as List)
      .map((e) => (e as Map<String, dynamic>)['species_id'] as String)
      .toSet();
  return TerritoryProgress(observed: distinct.length, total: total);
});

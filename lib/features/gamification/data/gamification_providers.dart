import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/level.dart';

/// Total des points cumulés par l'utilisateur connecté (Théo OU Axelle).
/// Avec le passage à 2 comptes dissociés, chacun a sa propre progression.
final accountTotalPointsProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentAuthUserProvider)?.id;
  if (userId == null) return 0;
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('observations')
      .select('points_earned')
      .eq('user_id', userId);
  return (rows as List).fold<int>(
    0,
    (acc, e) => acc + ((e as Map<String, dynamic>)['points_earned'] as int),
  );
});

/// Niveau de l'utilisateur connecté (calculé depuis ses points cumulés).
final accountLevelProvider = FutureProvider<LevelInfo>((ref) async {
  final points = await ref.watch(accountTotalPointsProvider.future);
  return computeLevel(points);
});

/// Progression sur un territoire : nb d'espèces distinctes observées par
/// l'utilisateur courant / nb total d'espèces curées dans la zone.
class TerritoryProgress {
  const TerritoryProgress({required this.observed, required this.total});

  final int observed;
  final int total;

  int get remaining => total - observed;
  double get fraction => total == 0 ? 0 : observed / total;
}

/// Progression de l'utilisateur connecté sur une zone donnée (short_code).
/// Le total d'espèces curées est commun, mais le nb observé est individuel
/// — chacun chasse sa propre complétion (cf. modèle 2 comptes dissociés).
final zoneProgressProvider =
    FutureProvider.family<TerritoryProgress, String>((ref, shortCode) async {
  final userId = ref.watch(currentAuthUserProvider)?.id;
  final client = ref.watch(supabaseClientProvider);

  // Récupère l'id de la zone via son short_code
  final zone = await client
      .from('zones')
      .select('id')
      .eq('short_code', shortCode)
      .single();
  final zoneId = zone['id'] as String;

  // Total : nb d'espèces curées sur la zone (commun aux deux users)
  final totalRows =
      await client.from('species_zones').select('species_id').eq('zone_id', zoneId);
  final total = (totalRows as List).length;

  if (userId == null) return TerritoryProgress(observed: 0, total: total);

  // Observed : nb d'espèces distinctes observées par CE user sur la zone
  final obsRows = await client
      .from('observations')
      .select('species_id')
      .eq('zone_id', zoneId)
      .eq('user_id', userId);
  final distinct = (obsRows as List)
      .map((e) => (e as Map<String, dynamic>)['species_id'] as String)
      .toSet();
  return TerritoryProgress(observed: distinct.length, total: total);
});

/// Progression sur la zone Oise (60) — kept for backward-compat.
/// Préférer zoneProgressProvider('60') ou ('02').
final oiseProgressProvider = FutureProvider<TerritoryProgress>(
  (ref) => ref.watch(zoneProgressProvider('60').future),
);

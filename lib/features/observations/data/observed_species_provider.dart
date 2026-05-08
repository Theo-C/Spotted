import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/supabase_client_provider.dart';

/// IDs des espèces déjà observées dans une zone (compte partagé,
/// pas de filtre par observateur).
/// Utilisé pour marquer les espèces "vues" dans la liste.
final observedSpeciesIdsInZoneProvider =
    FutureProvider.family<Set<String>, String>((ref, zoneId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('observations')
      .select('species_id')
      .eq('zone_id', zoneId);
  return (rows as List)
      .map((e) => (e as Map<String, dynamic>)['species_id'] as String)
      .toSet();
});

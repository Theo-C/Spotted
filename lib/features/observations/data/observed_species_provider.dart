import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';

/// IDs des espèces déjà observées par l'utilisateur courant dans une zone.
/// Utilisé pour marquer les espèces "vues" dans la liste — propre à chaque
/// user : chacun voit ses propres obs cochées.
///
/// `keepAlive` : évite un refetch à chaque navigation aller/retour vers la
/// liste espèces d'une même zone. Invalidation explicite gérée après INSERT
/// obs (cf. new_observation_screen) ou DELETE (cf. observation_detail_sheet)
/// → toujours à jour, mais sans re-hit BDD gratuit sur simple back+forward.
final observedSpeciesIdsInZoneProvider =
    FutureProvider.family<Set<String>, String>((ref, zoneId) async {
  ref.keepAlive();
  final userId = ref.watch(currentAuthUserProvider)?.id;
  if (userId == null) return <String>{};
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('observations')
      .select('species_id')
      .eq('zone_id', zoneId)
      .eq('user_id', userId);
  return (rows as List)
      .map((e) => (e as Map<String, dynamic>)['species_id'] as String)
      .toSet();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/observation.dart';
import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/providers/supabase_client_provider.dart';

/// Une observation enrichie de l'espèce associée et de sa rareté locale.
/// Utilisé pour afficher les markers colorés sur la carte Carnet.
class ObservationOnMap {
  const ObservationOnMap({
    required this.obs,
    this.species,
    this.rarity,
  });

  final Observation obs;
  final Species? species;
  final Rarity? rarity;
}

/// Toutes les observations du compte avec leur espèce et leur rareté
/// dans le territoire de l'observation.
///
/// Trois fetch en parallèle (observations, species_zones, species) puis join
/// côté client. Acceptable au MVP (volume faible) — à optimiser via une vue
/// SQL si on dépasse les 1000 obs.
final allObservationsForMapProvider =
    FutureProvider<List<ObservationOnMap>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  final results = await Future.wait([
    client.from('observations').select(),
    client.from('species_zones').select(),
    client.from('species').select(),
  ]);

  final obsRows = (results[0] as List).cast<Map<String, dynamic>>();
  final szRows = (results[1] as List).cast<Map<String, dynamic>>();
  final speciesRows = (results[2] as List).cast<Map<String, dynamic>>();

  final speciesById = {
    for (final s in speciesRows) s['id'] as String: Species.fromJson(s),
  };
  // Clé composite (species_id, zone_id) → rareté.
  final rarityByKey = <String, Rarity>{};
  for (final sz in szRows) {
    final speciesId = sz['species_id'] as String;
    final zoneId = sz['zone_id'] as String;
    final rarityStr = sz['rarity'] as String;
    final rarity =
        Rarity.values.firstWhere((r) => r.name == rarityStr);
    rarityByKey['$speciesId|$zoneId'] = rarity;
  }

  return obsRows.map((row) {
    final obs = Observation.fromJson(row);
    final key = obs.zoneId == null ? null : '${obs.speciesId}|${obs.zoneId}';
    return ObservationOnMap(
      obs: obs,
      species: speciesById[obs.speciesId],
      rarity: key == null ? null : rarityByKey[key],
    );
  }).toList();
});

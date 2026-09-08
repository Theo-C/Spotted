import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider est sous legacy.dart en Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/models/observation.dart';
import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';

/// ID d'observation que l'écran Carnet doit centrer et ouvrir à son prochain
/// affichage. Set par la mini-carte de la fiche espèce (tap → "voir dans le
/// carnet"), consommé + reset par JournalScreen une fois le focus effectué.
///
/// StateProvider car l'écriture vient de l'UI (bottom sheet) et la lecture
/// est cross-branch (le carnet est dans une autre StatefulShellBranch).
final focusedObservationIdProvider = StateProvider<String?>((ref) => null);

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

/// Toutes les observations de l'utilisateur courant avec leur espèce et
/// leur rareté dans le territoire de l'observation.
///
/// Le fetch observations est `.eq('user_id', currentUserId)` — la RLS 0023
/// filtre déjà côté serveur mais on double-guard côté client (defense-in-depth
/// pour couvrir un éventuel bug de policy Supabase, ou une session où la RLS
/// serait momentanément permissive).
///
/// Trois fetch en parallèle (observations, species_zones, species) puis join
/// côté client. Acceptable au MVP (volume faible) — à optimiser via une vue
/// SQL si on dépasse les 1000 obs.
final allObservationsForMapProvider =
    FutureProvider<List<ObservationOnMap>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentAuthUserProvider)?.id;
  if (userId == null) return const [];

  final results = await Future.wait([
    client.from('observations').select().eq('user_id', userId),
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

  // Filtre défensif côté client — si un bug RLS renvoyait des lignes hors-user,
  // on les rejette avant qu'elles atteignent la UI (menus supprimer/éditer
  // apparaîtraient sinon sur des obs d'un autre user).
  return obsRows
      .where((row) => row['user_id'] == userId)
      .map((row) {
    final obs = Observation.fromJson(row);
    final key = obs.zoneId == null ? null : '${obs.speciesId}|${obs.zoneId}';
    return ObservationOnMap(
      obs: obs,
      species: speciesById[obs.speciesId],
      rarity: key == null ? null : rarityByKey[key],
    );
  }).toList();
});

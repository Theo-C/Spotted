import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../territories/data/territory_progress_provider.dart';
import 'daily_species_repository.dart';

/// Espèce du jour résolue et enrichie pour l'UI — ligne DB + Species + rareté
/// dans la zone du tirage. Renvoyée par [dailySpeciesProvider].
class DailySpeciesResolved {
  const DailySpeciesResolved({
    required this.challenge,
    required this.species,
    required this.rarity,
  });

  final DailySpecies challenge;
  final Species species;
  final Rarity rarity;
}

/// Pondération du tirage aléatoire par rareté — favorise le commun/rare pour
/// que le défi reste atteignable au quotidien, tout en gardant une petite
/// chance de tirer un épique/légendaire (moment de surprise).
const Map<Rarity, double> _rarityWeights = {
  Rarity.common: 50,
  Rarity.rare: 30,
  Rarity.epic: 15,
  Rarity.legendary: 5,
};

/// Espèce du jour pour l'user courant. `null` si :
///   - pas connecté
///   - zone GPS non résolue
///   - catalogue vide dans la zone
///
/// Comportement :
///   1. Regarde en BDD si un tirage existe pour (userId, today).
///   2. Si oui → l'enrichit (species + rareté locale) et retourne.
///   3. Si non → tire dans le catalogue de la zone GPS courante (pondéré
///      rareté, privilégie les non-observées), insère en BDD, retourne.
///
/// Le tirage est stable jusqu'au lendemain — même si l'user change de zone
/// dans la journée, on garde l'espèce initialement tirée.
final dailySpeciesProvider =
    FutureProvider<DailySpeciesResolved?>((ref) async {
  final userId = ref.watch(currentAuthUserProvider)?.id;
  if (userId == null) return null;

  final today = DateTime.now();
  final repo = ref.watch(dailySpeciesRepositoryProvider);
  final client = ref.watch(supabaseClientProvider);

  // 1. Lookup existant.
  final existing =
      await repo.getForUserAndDate(userId: userId, date: today);
  if (existing != null) {
    return _enrich(client, existing);
  }

  // 2. Résout la zone courante (GPS ou cache), sans quoi on ne peut pas
  //    filtrer le catalogue "réaliste".
  final current = await ref.watch(currentTerritoryProvider.future);
  final zoneId = current.zone.id;

  // 3. Tire une espèce du catalogue de la zone.
  final picked = await _drawFromZone(
    client: client,
    userId: userId,
    zoneId: zoneId,
  );
  if (picked == null) return null; // Catalogue zone vide.

  // 4. Insère en BDD → stable jusqu'à demain.
  final ds = await repo.insert(
    userId: userId,
    date: today,
    zoneId: zoneId,
    speciesId: picked.species.id,
  );
  return DailySpeciesResolved(
    challenge: ds,
    species: picked.species,
    rarity: picked.rarity,
  );
});

/// True si [today] pour l'user courant, l'espèce [speciesId] est celle du
/// jour. Utilisé au submit d'une obs pour appliquer le bonus x2.
final isDailySpeciesProvider =
    Provider.family<bool, String>((ref, speciesId) {
  final ds = ref.watch(dailySpeciesProvider).asData?.value;
  return ds?.species.id == speciesId;
});

// -------------------------------------------------------------
// Helpers privés
// -------------------------------------------------------------

Future<DailySpeciesResolved> _enrich(
  dynamic client,
  DailySpecies ds,
) async {
  // Perf : un seul aller-retour pigeon via JOIN species + species_zones
  // (au lieu de 2 fetches séquentiels). Cas particulier zoneId null →
  // on lit juste l'espèce, rareté par défaut common.
  if (ds.zoneId == null) {
    final speciesRow = await client
        .from('species')
        .select()
        .eq('id', ds.speciesId)
        .single() as Map<String, dynamic>;
    return DailySpeciesResolved(
      challenge: ds,
      species: Species.fromJson(speciesRow),
      rarity: Rarity.common,
    );
  }

  // JOIN species + species_zones filtré sur (species_id, zone_id).
  // Rareté extraite du sous-object species_zones (peut être absent si
  // l'espèce n'est plus liée à la zone après le tirage).
  final row = await client
      .from('species')
      .select('*, species_zones(rarity, zone_id)')
      .eq('id', ds.speciesId)
      .single() as Map<String, dynamic>;
  final species = Species.fromJson(
    Map<String, dynamic>.from(row)..remove('species_zones'),
  );
  final szList = row['species_zones'] as List? ?? const [];
  Rarity rarity = Rarity.common;
  for (final sz in szList) {
    final m = sz as Map<String, dynamic>;
    if (m['zone_id'] == ds.zoneId) {
      rarity = Rarity.values
          .firstWhere((r) => r.name == (m['rarity'] as String));
      break;
    }
  }

  return DailySpeciesResolved(
    challenge: ds,
    species: species,
    rarity: rarity,
  );
}

typedef _Candidate = ({Species species, Rarity rarity});

/// Tire une espèce dans le catalogue de [zoneId] pour [userId] :
///   - Filtre les non-observées par l'user (priorité)
///   - Fallback sur toutes si l'user a tout vu
///   - Pondération par rareté (cf. [_rarityWeights])
Future<_Candidate?> _drawFromZone({
  required dynamic client,
  required String userId,
  required String zoneId,
}) async {
  // Fetch catalogue de la zone.
  final catalogRows = await client
      .from('species')
      .select('*, species_zones!inner(rarity, zone_id)')
      .eq('species_zones.zone_id', zoneId);
  final catalog = <_Candidate>[];
  for (final row in catalogRows as List) {
    final m = row as Map<String, dynamic>;
    final szList = m['species_zones'] as List;
    final rarityStr =
        (szList.first as Map<String, dynamic>)['rarity'] as String;
    final rarity = Rarity.values.firstWhere((r) => r.name == rarityStr);
    final speciesJson = Map<String, dynamic>.from(m)..remove('species_zones');
    catalog.add((species: Species.fromJson(speciesJson), rarity: rarity));
  }
  if (catalog.isEmpty) return null;

  // Fetch observées par l'user (toutes zones confondues — si tu l'as déjà
  // vue ailleurs, tu ne veux pas la re-tirer comme "à découvrir").
  final observedRows = await client
      .from('observations')
      .select('species_id')
      .eq('user_id', userId);
  final observedIds = <String>{
    for (final r in observedRows as List)
      (r as Map<String, dynamic>)['species_id'] as String,
  };

  var pool =
      catalog.where((c) => !observedIds.contains(c.species.id)).toList();
  // Tout est déjà vu → on re-tire dans le catalogue complet plutôt que
  // renvoyer null (permet une re-obs qui rapporte quand même via le bonus).
  if (pool.isEmpty) pool = catalog;

  // Tirage pondéré par rareté.
  final weights = [
    for (final c in pool) _rarityWeights[c.rarity] ?? 1.0,
  ];
  final total = weights.fold<double>(0, (a, b) => a + b);
  final r = Random().nextDouble() * total;
  var cumulative = 0.0;
  for (var i = 0; i < weights.length; i++) {
    cumulative += weights[i];
    if (r <= cumulative) return pool[i];
  }
  return pool.last; // fallback (rounding edge case)
}

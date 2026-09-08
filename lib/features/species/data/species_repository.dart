import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/species.dart';
import '../../../shared/providers/supabase_client_provider.dart';

class SpeciesRepository {
  SpeciesRepository(this._client);

  final SupabaseClient _client;

  /// Toutes les espèces présentes dans la zone (via jointure species_zones).
  /// Note : ne renvoie pas la rareté locale — pour ça, requêter species_zones
  /// séparément ou créer un DTO joint plus tard.
  Future<List<Species>> getByZone(String zoneId) async {
    final rows = await _client
        .from('species')
        .select('*, species_zones!inner(zone_id)')
        .eq('species_zones.zone_id', zoneId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Species.fromJson)
        .toList();
  }

  /// Lookup par nom scientifique. Renvoie null si l'espèce n'est pas encore
  /// au catalogue. Utilisé au submit du form d'ajout pour détecter les
  /// doublons — dans ce cas on ne CREATE pas, on ajoute simplement le lien
  /// vers les zones manquantes dans `species_zones`.
  Future<Species?> getByScientificName(String scientificName) async {
    final row = await _client
        .from('species')
        .select()
        .eq('scientific_name', scientificName)
        .maybeSingle();
    if (row == null) return null;
    return Species.fromJson(row);
  }

  /// Zones auxquelles une espèce est déjà rattachée. Utilisé pour ne pas
  /// re-insérer un lien species_zones existant (violation de la contrainte
  /// unique (species_id, zone_id)).
  Future<Set<String>> getZoneIdsForSpecies(String speciesId) async {
    final rows = await _client
        .from('species_zones')
        .select('zone_id')
        .eq('species_id', speciesId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['zone_id'] as String)
        .toSet();
  }

  Future<Species> getById(String id) async {
    final row = await _client
        .from('species')
        .select()
        .eq('id', id)
        .single();
    return Species.fromJson(row);
  }

  Future<Species> create({
    required String commonName,
    required String scientificName,
    required String categoryId,
    String? description,
    String? tips,
    String? photoUrl,
    String? createdByUserId,
  }) async {
    final row = await _client
        .from('species')
        .insert({
          'common_name': commonName,
          'scientific_name': scientificName,
          'category_id': categoryId,
          'description': description,
          'tips': tips,
          'photo_url': photoUrl,
          'created_by_user_id': createdByUserId,
        })
        .select()
        .single();
    return Species.fromJson(row);
  }

  Future<Species> update(Species species) async {
    final json = species.toJson()
      ..remove('id')
      ..remove('created_at');
    final row = await _client
        .from('species')
        .update(json)
        .eq('id', species.id)
        .select()
        .single();
    return Species.fromJson(row);
  }
}

final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
  return SpeciesRepository(ref.watch(supabaseClientProvider));
});

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

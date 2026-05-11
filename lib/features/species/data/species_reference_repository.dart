import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/species_reference.dart';
import '../../../shared/providers/supabase_client_provider.dart';

/// Accès à la banque de référence `species_reference`.
/// Utilisé par `_AddSpeciesDialog` pour pré-remplir les champs description,
/// tips, catégorie, rareté et photo quand l'user ajoute une espèce déjà
/// connue de la banque.
class SpeciesReferenceRepository {
  SpeciesReferenceRepository(this._client);

  final SupabaseClient _client;

  /// Lookup exact par scientific_name (clé primaire de la table).
  /// Renvoie null si l'espèce n'est pas dans la banque de référence.
  Future<SpeciesReference?> getByScientificName(String scientificName) async {
    final row = await _client
        .from('species_reference')
        .select()
        .eq('scientific_name', scientificName)
        .maybeSingle();
    if (row == null) return null;
    return SpeciesReference.fromJson(row);
  }

  /// Recherche sur common_name OU scientific_name, insensible à la casse
  /// ET aux accents. Passe par la RPC `search_species_reference` (cf.
  /// migration 0016) qui applique unaccent() côté Postgres — PostgREST ne
  /// sait pas appeler unaccent() dans un filtre `.or()` ordinaire. La RPC
  /// limite à 10 résultats côté serveur.
  Future<List<SpeciesReference>> search(String query, {int limit = 10}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final response = await _client.rpc<dynamic>(
      'search_species_reference',
      params: {'q': q},
    );
    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map(SpeciesReference.fromJson).toList();
  }
}

final speciesReferenceRepositoryProvider =
    Provider<SpeciesReferenceRepository>((ref) {
  return SpeciesReferenceRepository(ref.watch(supabaseClientProvider));
});

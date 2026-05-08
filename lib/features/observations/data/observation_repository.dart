import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/observation.dart';
import '../../../shared/providers/supabase_client_provider.dart';

class ObservationRepository {
  ObservationRepository(this._client);

  final SupabaseClient _client;

  /// Toutes les observations d'un user (Théo OU Axelle), tri date desc.
  Future<List<Observation>> getByUser(String userId) async {
    final rows = await _client
        .from('observations')
        .select()
        .eq('user_id', userId)
        .order('observed_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Observation.fromJson)
        .toList();
  }

  /// Toutes les observations (les deux users), tri date desc.
  /// Utilisé pour le carnet géo partagé.
  Future<List<Observation>> getAll() async {
    final rows = await _client
        .from('observations')
        .select()
        .order('observed_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Observation.fromJson)
        .toList();
  }

  /// Crée une observation. La valeur de is_first_for_user est ignorée :
  /// le trigger trg_observations_is_first la recalcule côté serveur.
  /// points_earned est figé par le client (logique gamification).
  Future<Observation> create({
    required String userId,
    required String speciesId,
    String? zoneId,
    required DateTime observedAt,
    required double latitude,
    required double longitude,
    String? photoUrl,
    Map<String, dynamic>? photoExifData,
    required int pointsEarned,
  }) async {
    final row = await _client
        .from('observations')
        .insert({
          'user_id': userId,
          'species_id': speciesId,
          'zone_id': zoneId,
          'observed_at': observedAt.toIso8601String(),
          'latitude': latitude,
          'longitude': longitude,
          'photo_url': photoUrl,
          'photo_exif_data': photoExifData,
          'points_earned': pointsEarned,
        })
        .select()
        .single();
    return Observation.fromJson(row);
  }

  /// Met à jour une observation (cas typique : ajout photo rétroactif → photo_url
  /// + points_earned bumpé). Ne touche pas aux colonnes read-only (id, created_at,
  /// is_first_for_user calculé serveur).
  Future<Observation> update(Observation observation) async {
    final json = observation.toJson()
      ..remove('id')
      ..remove('created_at')
      ..remove('is_first_for_user');
    final row = await _client
        .from('observations')
        .update(json)
        .eq('id', observation.id)
        .select()
        .single();
    return Observation.fromJson(row);
  }
}

final observationRepositoryProvider = Provider<ObservationRepository>((ref) {
  return ObservationRepository(ref.watch(supabaseClientProvider));
});

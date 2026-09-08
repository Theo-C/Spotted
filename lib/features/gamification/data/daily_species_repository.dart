import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/supabase_client_provider.dart';

/// Ligne de la table daily_species — l'espèce tirée pour un user à une date.
class DailySpecies {
  const DailySpecies({
    required this.userId,
    required this.challengeDate,
    this.zoneId,
    required this.speciesId,
    required this.createdAt,
  });

  final String userId;
  final DateTime challengeDate;
  final String? zoneId;
  final String speciesId;
  final DateTime createdAt;

  factory DailySpecies.fromJson(Map<String, dynamic> json) {
    return DailySpecies(
      userId: json['user_id'] as String,
      challengeDate: DateTime.parse(json['challenge_date'] as String),
      zoneId: json['zone_id'] as String?,
      speciesId: json['species_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DailySpeciesRepository {
  DailySpeciesRepository(this._client);

  final SupabaseClient _client;

  /// Formate une DateTime en `yyyy-MM-dd` local — la clé de la table est un
  /// `date` PostgreSQL, donc pas d'heure. On garde la date LOCALE (Paris)
  /// pour que "aujourd'hui" corresponde bien à la journée vécue par l'user.
  static String formatDate(DateTime date) {
    final d = date.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Cherche l'entrée du jour pour l'user courant. null si pas encore tirée.
  Future<DailySpecies?> getForUserAndDate({
    required String userId,
    required DateTime date,
  }) async {
    final row = await _client
        .from('daily_species')
        .select()
        .eq('user_id', userId)
        .eq('challenge_date', formatDate(date))
        .maybeSingle();
    if (row == null) return null;
    return DailySpecies.fromJson(row);
  }

  /// Insère le tirage du jour. Idempotent grâce au PK (user_id + date) —
  /// on utilise `insert(..., ignoreDuplicates)` en cas de course entre deux
  /// ouvertures rapides de l'app (rare mais possible).
  Future<DailySpecies> insert({
    required String userId,
    required DateTime date,
    String? zoneId,
    required String speciesId,
  }) async {
    final row = await _client
        .from('daily_species')
        .upsert(
          {
            'user_id': userId,
            'challenge_date': formatDate(date),
            'zone_id': zoneId,
            'species_id': speciesId,
          },
          onConflict: 'user_id,challenge_date',
          ignoreDuplicates: false,
        )
        .select()
        .single();
    return DailySpecies.fromJson(row);
  }
}

final dailySpeciesRepositoryProvider =
    Provider<DailySpeciesRepository>((ref) {
  return DailySpeciesRepository(ref.watch(supabaseClientProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/supabase_client_provider.dart';

/// Snapshot d'un badge unlocked en BDD (rangée de la table user_badges).
class EarnedBadge {
  const EarnedBadge({required this.badgeId, required this.earnedAt});

  final String badgeId;
  final DateTime earnedAt;

  factory EarnedBadge.fromRow(Map<String, dynamic> row) => EarnedBadge(
        badgeId: row['badge_id'] as String,
        earnedAt: DateTime.parse(row['earned_at'] as String),
      );
}

/// Accès à la table `user_badges` : qui a unlocked quel badge et quand.
class UserBadgesRepository {
  UserBadgesRepository(this._client);

  final SupabaseClient _client;

  Future<List<EarnedBadge>> getEarnedForUser(String userId) async {
    final rows = await _client
        .from('user_badges')
        .select('badge_id, earned_at')
        .eq('user_id', userId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(EarnedBadge.fromRow)
        .toList();
  }

  /// Insert un nouveau unlock. Idempotent : si la ligne existe déjà
  /// (PK = (user_id, badge_id)), on ignore le conflit.
  Future<void> insertEarned({
    required String userId,
    required String badgeId,
  }) async {
    await _client.from('user_badges').upsert(
      {
        'user_id': userId,
        'badge_id': badgeId,
        'earned_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,badge_id',
      ignoreDuplicates: true,
    );
  }
}

final userBadgesRepositoryProvider = Provider<UserBadgesRepository>((ref) {
  return UserBadgesRepository(ref.watch(supabaseClientProvider));
});

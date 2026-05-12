import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/supabase_client_provider.dart';

/// Snapshot d'un claim de quête journalière (table user_quest_claims).
/// Présence = la quête a déjà été récompensée pour ce user à cette date,
/// pas besoin de re-créditer.
class QuestClaim {
  const QuestClaim({
    required this.questId,
    required this.claimDate,
    required this.xpCredited,
  });

  final String questId;
  final DateTime claimDate;
  final int xpCredited;

  factory QuestClaim.fromRow(Map<String, dynamic> row) => QuestClaim(
        questId: row['quest_id'] as String,
        claimDate: DateTime.parse(row['claim_date'] as String),
        xpCredited: row['xp_credited'] as int,
      );
}

class UserQuestClaimsRepository {
  UserQuestClaimsRepository(this._client);

  final SupabaseClient _client;

  /// Claims du jour pour cet user (filtré sur la date locale du jour).
  Future<List<QuestClaim>> getTodayClaims({
    required String userId,
    required DateTime today,
  }) async {
    final dateOnly =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final rows = await _client
        .from('user_quest_claims')
        .select('quest_id, claim_date, xp_credited')
        .eq('user_id', userId)
        .eq('claim_date', dateOnly.substring(0, 10));
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(QuestClaim.fromRow)
        .toList();
  }

  /// Insère un claim. Idempotent via PK (user_id, quest_id, claim_date).
  Future<void> insertClaim({
    required String userId,
    required String questId,
    required DateTime claimDate,
    required int xpCredited,
  }) async {
    final dateOnly = DateTime(claimDate.year, claimDate.month, claimDate.day)
        .toIso8601String()
        .substring(0, 10);
    await _client.from('user_quest_claims').upsert(
      {
        'user_id': userId,
        'quest_id': questId,
        'claim_date': dateOnly,
        'xp_credited': xpCredited,
      },
      onConflict: 'user_id,quest_id,claim_date',
      ignoreDuplicates: true,
    );
  }
}

final userQuestClaimsRepositoryProvider =
    Provider<UserQuestClaimsRepository>((ref) {
  return UserQuestClaimsRepository(ref.watch(supabaseClientProvider));
});

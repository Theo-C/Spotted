import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/zone.dart';
import '../../../shared/providers/supabase_client_provider.dart';

class ZoneRepository {
  ZoneRepository(this._client);

  final SupabaseClient _client;

  Future<List<Zone>> getAll() async {
    final rows = await _client.from('zones').select();
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Zone.fromJson)
        .toList();
  }

  Future<Zone> getById(String id) async {
    final row = await _client
        .from('zones')
        .select()
        .eq('id', id)
        .single();
    return Zone.fromJson(row);
  }
}

final zoneRepositoryProvider = Provider<ZoneRepository>((ref) {
  return ZoneRepository(ref.watch(supabaseClientProvider));
});

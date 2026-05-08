import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import 'species_with_rarity_provider.dart';

/// Détail d'une espèce dans le contexte d'une zone (avec rareté locale).
final speciesDetailProvider = FutureProvider.family<
    SpeciesWithRarity,
    ({String speciesId, String zoneId})>((ref, params) async {
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('species')
      .select('*, species_zones!inner(rarity, zone_id)')
      .eq('id', params.speciesId)
      .eq('species_zones.zone_id', params.zoneId)
      .single();

  final szList = row['species_zones'] as List;
  final rarityStr = (szList.first as Map<String, dynamic>)['rarity'] as String;
  final rarity = Rarity.values.firstWhere((r) => r.name == rarityStr);
  final speciesJson = Map<String, dynamic>.from(row)..remove('species_zones');
  return (species: Species.fromJson(speciesJson), rarity: rarity);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/providers/supabase_client_provider.dart';

typedef SpeciesWithRarity = ({Species species, Rarity rarity});

/// Espèces d'une catégorie présentes dans une zone, enrichies de leur
/// rareté locale (depuis species_zones).
final speciesByCategoryInZoneProvider = FutureProvider.family<
    List<SpeciesWithRarity>,
    ({String zoneId, String categoryId})>((ref, params) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('species')
      .select('*, species_zones!inner(rarity, zone_id)')
      .eq('category_id', params.categoryId)
      .eq('species_zones.zone_id', params.zoneId);

  return (rows as List).map((row) {
    final m = row as Map<String, dynamic>;
    final szList = m['species_zones'] as List;
    final rarityStr = (szList.first as Map<String, dynamic>)['rarity'] as String;
    final rarity = Rarity.values.firstWhere((r) => r.name == rarityStr);
    final speciesJson = Map<String, dynamic>.from(m)..remove('species_zones');
    return (species: Species.fromJson(speciesJson), rarity: rarity);
  }).toList();
});

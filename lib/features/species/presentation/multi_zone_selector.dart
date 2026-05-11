import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/zone.dart';
import '../../territories/data/zone_repository.dart';

/// Sélecteur multi-territoires sous forme de [FilterChip]s. Utilisé à la
/// création d'une nouvelle espèce pour cocher les zones auxquelles l'espèce
/// sera liée via `species_zones` (avec la même rareté pour toutes).
///
/// Le set [selectedIds] est piloté par l'écran parent — clique = toggle.
class MultiZoneSelector extends ConsumerWidget {
  const MultiZoneSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(_allZonesProvider);
    return zonesAsync.when(
      loading: () => const SizedBox(
        height: 32,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: forestGreen,
            ),
          ),
        ),
      ),
      error: (e, _) => Text(
        'Territoires indisponibles',
        style: GoogleFonts.karla(color: textMuted, fontSize: 12),
      ),
      data: (zones) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: zones.map((z) {
          final selected = selectedIds.contains(z.id);
          return FilterChip(
            label: Text('${z.name} (${z.shortCode})'),
            selected: selected,
            onSelected: (sel) {
              final next = Set<String>.from(selectedIds);
              if (sel) {
                next.add(z.id);
              } else {
                next.remove(z.id);
              }
              onChanged(next);
            },
            labelStyle: GoogleFonts.karla(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? surfaceBase : forestGreen,
            ),
            backgroundColor: surfaceCard,
            selectedColor: forestGreen,
            checkmarkColor: surfaceBase,
            side: BorderSide(
              color: selected ? forestGreen : const Color(0xFFE8E0CE),
              width: 1.2,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }
}

/// Toutes les zones curées (Oise, Aisne, …). Utilisé par les sélecteurs
/// de territoires à la création d'espèce.
final _allZonesProvider = FutureProvider<List<Zone>>((ref) async {
  return ref.watch(zoneRepositoryProvider).getAll();
});

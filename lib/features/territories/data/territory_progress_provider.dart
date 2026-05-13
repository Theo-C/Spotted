import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/location_service.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import 'category_repository.dart';
import 'geocoding_service.dart';
import 'zone_repository.dart';

/// Toutes les zones du pays courant (MVP : 60 Oise + 02 Aisne).
/// Source de vérité pour itérer les territoires sur la Home (vs hard-codé
/// avant). Quand on ajoutera la Somme, il suffira de l'insérer en BDD.
///
/// Tri stable par shortCode ASC ; le terrain mis en avant sur la Home n'est
/// PLUS dérivé de ce tri mais de [currentTerritoryProvider] (position GPS).
final allZonesProvider = FutureProvider<List<Zone>>((ref) async {
  final zones = await ref.watch(zoneRepositoryProvider).getAll();
  zones.sort((a, b) => (a.shortCode ?? '').compareTo(b.shortCode ?? ''));
  return zones;
});

/// Résultat de la résolution territoriale "ici, maintenant".
/// [fromGps] = true si la position vient d'une lecture GPS réussie cette
/// session ; false si on est tombé sur le fallback (cache prefs ou défaut).
typedef CurrentTerritory = ({Zone zone, bool fromGps});

const _kLastLat = 'last_known_lat';
const _kLastLng = 'last_known_lng';

/// Détermine le terrain "courant" pour mettre en hero sur la Home.
///
/// Ordre de résolution :
///   1. Lecture GPS fresh → cache la position + reverse-geocode + match zone.
///   2. Si GPS indisponible (denied/off) → reprend la dernière position
///      mémorisée dans SharedPreferences + même pipeline.
///   3. Si rien ne marche (1ʳᵉ ouverture sans GPS, hors zone curée…) →
///      retombe sur la 1ʳᵉ zone de allZonesProvider (fromGps: false).
///
/// L'objectif est d'éviter le tag "DOMICILE/VOISIN" statique : le hero
/// reflète où l'user EST, pas une étiquette éditoriale.
final currentTerritoryProvider = FutureProvider<CurrentTerritory>((ref) async {
  final zones = await ref.watch(allZonesProvider.future);
  if (zones.isEmpty) {
    throw StateError('Aucune zone configurée');
  }

  // 1. Tente une lecture GPS fresh. Si succès, on persiste la position
  //    pour les prochaines ouvertures (cas GPS off).
  double? lat;
  double? lng;
  bool fromGps = false;
  final location = await ref.read(locationServiceProvider).getCurrentPosition();
  if (location is LocationSuccess) {
    lat = location.lat;
    lng = location.lng;
    fromGps = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLastLat, lat);
    await prefs.setDouble(_kLastLng, lng);
  } else {
    // 2. GPS indisponible (denied, off, error) → cache prefs.
    final prefs = await SharedPreferences.getInstance();
    lat = prefs.getDouble(_kLastLat);
    lng = prefs.getDouble(_kLastLng);
  }

  // 3. Aucune position disponible (1ère ouverture + GPS refusé) → fallback.
  if (lat == null || lng == null) {
    return (zone: zones.first, fromGps: false);
  }

  // Reverse-geocode + match nom de région ↔ nom de zone curée.
  try {
    final geo = await ref
        .read(geocodingServiceProvider)
        .reverseGeocode(lat: lat, lng: lng);
    final region = geo?.region;
    if (region != null) {
      final matched = zones.cast<Zone?>().firstWhere(
            (z) => z!.name == region,
            orElse: () => null,
          );
      if (matched != null) {
        return (zone: matched, fromGps: fromGps);
      }
    }
  } catch (_) {
    // Réseau / quota Mapbox → on retombe sur le fallback.
  }

  // Position connue mais hors zone curée (ex: vacances Var) → fallback.
  return (zone: zones.first, fromGps: false);
});

/// Zone par short_code (ex: '60' pour Oise, '02' pour Aisne).
/// FutureProvider.family plutôt qu'une constante car les UUIDs sont
/// générés par Supabase (pas connus à la compilation).
final zoneByShortCodeProvider =
    FutureProvider.family<Zone, String>((ref, shortCode) async {
  final zones = await ref.watch(zoneRepositoryProvider).getAll();
  return zones.firstWhere((z) => z.shortCode == shortCode);
});

/// Zone Oise (60) — kept for backward-compat. Prefer zoneByShortCodeProvider.
final oiseZoneProvider =
    FutureProvider<Zone>((ref) => ref.watch(zoneByShortCodeProvider('60').future));

/// Progression par catégorie pour une zone donnée.
class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.observed,
    required this.total,
  });

  final Category category;
  final int observed;
  final int total;

  int get remaining => total - observed;
  double get fraction => total == 0 ? 0 : observed / total;
}

/// Liste des catégories enrichies de leur progression sur la zone donnée.
/// Progression individuelle (modèle 2 comptes dissociés depuis 2026-05-10) :
/// chaque user voit sa propre complétion par catégorie.
final categoriesWithProgressProvider =
    FutureProvider.family<List<CategoryProgress>, String>((ref, zoneId) async {
  final userId = ref.watch(currentAuthUserProvider)?.id;
  final client = ref.watch(supabaseClientProvider);
  final categories = await ref.watch(categoryRepositoryProvider).getAll();

  // Total : species_zones de la zone, on récupère le category_id via jointure.
  // (Total commun aux deux users — c'est le catalogue curé de la zone.)
  final totalRows = await client
      .from('species_zones')
      .select('species_id, species!inner(category_id)')
      .eq('zone_id', zoneId);

  // Observed : observations de l'utilisateur courant sur la zone.
  // Sans userId (pas connecté), on retourne 0 observation côté UI.
  final obsRows = userId == null
      ? const <Map<String, dynamic>>[]
      : await client
          .from('observations')
          .select('species_id, species!inner(category_id)')
          .eq('zone_id', zoneId)
          .eq('user_id', userId);

  final totalByCategory = <String, int>{};
  for (final row in totalRows as List) {
    final categoryId = ((row as Map<String, dynamic>)['species']
        as Map<String, dynamic>)['category_id'] as String;
    totalByCategory[categoryId] = (totalByCategory[categoryId] ?? 0) + 1;
  }

  final observedByCategory = <String, Set<String>>{};
  for (final row in obsRows as List) {
    final m = row as Map<String, dynamic>;
    final speciesId = m['species_id'] as String;
    final categoryId =
        (m['species'] as Map<String, dynamic>)['category_id'] as String;
    observedByCategory.putIfAbsent(categoryId, () => {}).add(speciesId);
  }

  return categories
      .map(
        (c) => CategoryProgress(
          category: c,
          total: totalByCategory[c.id] ?? 0,
          observed: observedByCategory[c.id]?.length ?? 0,
        ),
      )
      .toList();
});

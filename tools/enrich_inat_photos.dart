// ignore_for_file: avoid_print
//
// Script one-shot d'enrichissement de la table `species_reference` avec les
// photos et la validation taxonomique via l'API iNaturalist.
//
// Pour chaque ligne où photo_url IS NULL :
//   1. GET https://api.inaturalist.org/v1/taxa?q={scientific_name}&locale=fr
//   2. Si match exact sur scientific_name → on prend default_photo.medium_url
//      + preferred_common_name (FR) pour vérification
//   3. PATCH species_reference avec photo_url
//   4. Si common_name iNat ≠ common_name DB → log warning (suggère hallucination
//      Claude ou orthographe non-standard)
//   5. Si pas trouvé du tout dans iNat → log error (probable hallucination
//      du scientific_name à corriger manuellement)
//
// Usage (PowerShell) :
//   $env:SUPABASE_URL = "https://xxxxx.supabase.co"
//   $env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..." # depuis Dashboard → Settings → API
//   dart run tools/enrich_inat_photos.dart
//
// Throttle : 1 req/sec côté iNat (60/min, sous la limite recommandée de 100).
// Pour 260 espèces → ~5 min total.

import 'dart:io';
import 'package:dio/dio.dart';

const _inatApi = 'https://api.inaturalist.org/v1/taxa';
const _throttleMs = 1000;

Future<void> main() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    _err('SUPABASE_URL env var manquante');
    exit(1);
  }
  if (serviceKey == null || serviceKey.isEmpty) {
    _err(
      'SUPABASE_SERVICE_ROLE_KEY env var manquante. À récupérer dans '
      'Supabase Dashboard → Project Settings → API → service_role secret.',
    );
    exit(1);
  }

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // 1. Récupère toutes les espèces sans photo
  print('Fetching species_reference rows where photo_url IS NULL…');
  final List<Map<String, dynamic>> species;
  try {
    final response = await dio.get<List<dynamic>>(
      '$supabaseUrl/rest/v1/species_reference',
      queryParameters: {
        'select': 'scientific_name,common_name',
        'photo_url': 'is.null',
        'order': 'scientific_name.asc',
      },
      options: Options(
        headers: {
          'apikey': serviceKey,
          'Authorization': 'Bearer $serviceKey',
        },
      ),
    );
    species = (response.data ?? [])
        .cast<Map<String, dynamic>>();
  } on DioException catch (e) {
    _err('Supabase fetch failed: ${e.message} (${e.response?.statusCode})');
    exit(1);
  }

  print('Found ${species.length} species to enrich.\n');
  if (species.isEmpty) {
    print('Nothing to do.');
    exit(0);
  }

  final notFound = <String>[];
  final nameMismatch = <String>[];
  var enriched = 0;
  var noPhoto = 0;

  for (var i = 0; i < species.length; i++) {
    final sp = species[i];
    final scientificName = sp['scientific_name'] as String;
    final commonNameDb = sp['common_name'] as String;
    final prefix = '[${i + 1}/${species.length}]';

    stdout.write('$prefix $scientificName ($commonNameDb)…');

    // 2. Appel iNat. On exige un match EXACT sur scientific_name (champ
    // "name" iNat) — sinon on skip plutôt que de prendre un résultat fuzzy
    // qui peut être à côté de la plaque (cf. bug Bubo bubo → Grèbe huppé
    // avec l'ancien fallback `results.first`). per_page bumped à 30 pour
    // augmenter les chances de trouver l'exact match parmi les résultats.
    Map<String, dynamic>? match;
    try {
      final response = await dio.get<Map<String, dynamic>>(
        _inatApi,
        queryParameters: {
          'q': scientificName,
          'rank': 'species',
          'locale': 'fr',
          'per_page': 100,
        },
      );
      final results = ((response.data?['results'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
      for (final r in results) {
        if ((r['name'] as String?) == scientificName) {
          match = r;
          break;
        }
      }
      // Pas de fallback fuzzy : si pas d'exact match → match reste null.
    } on DioException catch (e) {
      stdout.writeln(' ✗ iNat error: ${e.message}');
      notFound.add(scientificName);
      await Future<void>.delayed(Duration(milliseconds: _throttleMs));
      continue;
    }

    if (match == null) {
      stdout.writeln(' ✗ NOT FOUND in iNat (probable hallucination Claude)');
      notFound.add(scientificName);
      await Future<void>.delayed(Duration(milliseconds: _throttleMs));
      continue;
    }

    // Vérifie cohérence du common_name FR vs DB
    final inatCommonName = match['preferred_common_name'] as String?;
    if (inatCommonName != null &&
        inatCommonName.toLowerCase() != commonNameDb.toLowerCase()) {
      nameMismatch.add(
        '$scientificName : DB="$commonNameDb" vs iNat="$inatCommonName"',
      );
    }

    // 3. Récupère l'URL photo
    final photoUrl =
        (match['default_photo'] as Map<String, dynamic>?)?['medium_url']
            as String?;
    if (photoUrl == null) {
      stdout.writeln(' ⚠ Found but no default_photo');
      noPhoto++;
      await Future<void>.delayed(Duration(milliseconds: _throttleMs));
      continue;
    }

    // 4. PATCH la ligne avec le photo_url
    try {
      await dio.patch<void>(
        '$supabaseUrl/rest/v1/species_reference',
        queryParameters: {
          'scientific_name': 'eq.$scientificName',
        },
        data: {'photo_url': photoUrl},
        options: Options(
          headers: {
            'apikey': serviceKey,
            'Authorization': 'Bearer $serviceKey',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
        ),
      );
      stdout.writeln(' ✓');
      enriched++;
    } on DioException catch (e) {
      stdout.writeln(' ✗ Supabase PATCH failed: ${e.message}');
    }

    // Throttle pour respecter iNat
    await Future<void>.delayed(Duration(milliseconds: _throttleMs));
  }

  // Résumé final
  print('\n=== Résumé ===');
  print('Total traité    : ${species.length}');
  print('Enrichies (✓)   : $enriched');
  print('Sans photo (⚠)  : $noPhoto');
  print('Non trouvées (✗): ${notFound.length}');
  print('Noms divergents : ${nameMismatch.length}');

  if (notFound.isNotEmpty) {
    print('\n--- À CORRIGER (scientific_name non trouvé dans iNat) ---');
    for (final n in notFound) {
      print('  - $n');
    }
    print(
      '\nVérifie ces espèces : soit le nom est mal orthographié, soit '
      'Claude a halluciné un binominal qui n\'existe pas. Tu peux les '
      "UPDATE ou DELETE manuellement dans Supabase SQL Editor.",
    );
  }

  if (nameMismatch.isNotEmpty) {
    print(
      '\n--- À VÉRIFIER (common_name FR diverge entre DB et iNat) ---',
    );
    for (final n in nameMismatch) {
      print('  - $n');
    }
    print(
      '\nDans la plupart des cas iNat a raison (nomenclature française '
      "standardisée). Tu peux UPDATE les common_name divergents si tu "
      'préfères la version iNat.',
    );
  }
}

void _err(String msg) {
  stderr.writeln('ERROR: $msg');
}

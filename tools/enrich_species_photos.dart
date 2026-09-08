// ignore_for_file: avoid_print
//
// Script one-shot d'enrichissement de la table `public.species` avec les
// photos iNaturalist. Miroir de `enrich_inat_photos.dart` (qui cible
// `species_reference`) — même logique, autre table.
//
// À lancer après une migration qui ajoute de nouvelles espèces au catalogue
// (typiquement : seed d'un nouveau territoire comme migration 0018 pour la
// Savoie). Traite uniquement les lignes où photo_url IS NULL, donc
// idempotent et safe à relancer.
//
// Pour chaque ligne :
//   1. GET https://api.inaturalist.org/v1/taxa?q={scientific_name}&locale=fr
//   2. Match EXACT sur scientific_name (pas de fuzzy — évite les faux
//      positifs type Bubo bubo → Grèbe huppé)
//   3. PATCH species avec default_photo.medium_url
//   4. Warning si preferred_common_name FR diverge du common_name DB
//   5. Log erreur si pas trouvé (hallucination scientific_name à corriger)
//
// Usage (PowerShell) :
//   $env:SUPABASE_URL = "https://xxxxx.supabase.co"
//   $env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..." # Dashboard → Settings → API
//   dart run tools/enrich_species_photos.dart
//
// Throttle : 1 req/sec côté iNat (60/min, sous la limite de 100).

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

  // 1. Récupère toutes les espèces sans photo dans le catalogue.
  print('Fetching public.species rows where photo_url IS NULL…');
  final List<Map<String, dynamic>> species;
  try {
    final response = await dio.get<List<dynamic>>(
      '$supabaseUrl/rest/v1/species',
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
    species = (response.data ?? []).cast<Map<String, dynamic>>();
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

    // 2. Appel iNat : match EXACT sur scientific_name uniquement.
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
    } on DioException catch (e) {
      stdout.writeln(' ✗ iNat error: ${e.message}');
      notFound.add(scientificName);
      await Future<void>.delayed(Duration(milliseconds: _throttleMs));
      continue;
    }

    if (match == null) {
      stdout.writeln(' ✗ NOT FOUND in iNat');
      notFound.add(scientificName);
      await Future<void>.delayed(Duration(milliseconds: _throttleMs));
      continue;
    }

    // Vérifie cohérence common_name FR vs DB (warning only)
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
        '$supabaseUrl/rest/v1/species',
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
      '\nSoit le nom est mal orthographié, soit obsolète. UPDATE manuel '
      'dans Supabase SQL Editor si besoin.',
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
      '\niNat suit généralement la nomenclature FR standardisée. Tu peux '
      'UPDATE les common_name divergents si tu préfères la version iNat.',
    );
  }
}

void _err(String msg) {
  stderr.writeln('ERROR: $msg');
}

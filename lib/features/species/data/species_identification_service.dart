import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/env.dart';
import '../domain/species_identification.dart';

/// Identifie une espèce depuis une photo via Claude Vision (Anthropic API).
///
/// Coût indicatif (Haiku 4.5) : ~0.002 $/photo. Quota raisonnable pour 2 users.
///
/// ⚠️ La clé API est embarquée dans l'APK (`.env` est asset Flutter). Pour un
/// déploiement public, proxifier via une edge function Supabase.
class SpeciesIdentificationService {
  SpeciesIdentificationService(this._dio);

  final Dio _dio;

  static const _model = 'claude-haiku-4-5';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  static const _systemPrompt = '''
Tu es un expert naturaliste français spécialisé dans la faune sauvage européenne.
Tu identifies les espèces (oiseaux, mammifères, reptiles, chiroptères) depuis une photo.

Tu réponds UNIQUEMENT en JSON valide, sans texte hors-JSON, sans bloc markdown,
suivant exactement ce schéma :

{
  "detected": true|false,
  "common_name": "Nom français standard (ex: 'Buse variable')",
  "scientific_name": "Nom binominal latin (ex: 'Buteo buteo')",
  "category_key": "birds" | "mammals" | "reptiles" | "bats",
  "rarity_key": "common" | "rare" | "epic" | "legendary",
  "confidence": 0.0..1.0,
  "rationale": "Une phrase courte (max 25 mots) justifiant l'identification"
}

Conventions raretés (en France métropolitaine) :
- common : espèce courante, visible toute l'année (buse variable, héron cendré)
- rare : présence localisée ou en déclin (épervier, chouette effraie)
- epic : espèce remarquable, à certaines saisons/lieux (faucon pèlerin, huppe fasciée)
- legendary : très discrète, limite d'aire, passage migratoire (balbuzard, butor étoilé)

Si la photo ne montre pas un animal sauvage identifiable (paysage, plante,
animal domestique, photo floue), renvoie "detected": false avec champs vides
sauf "rationale" qui explique pourquoi.

Si tu hésites entre plusieurs espèces, donne la plus probable avec confidence < 0.6.
''';

  /// Identifie l'espèce sur [photo].
  /// Renvoie null en cas d'erreur (réseau, parsing). L'app continue alors
  /// en mode manuel.
  Future<SpeciesIdentification?> identifyFromFile(File photo) async {
    try {
      final bytes = await photo.readAsBytes();
      final encoded = base64Encode(bytes);
      final mediaType = _detectMediaType(photo.path);

      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        options: Options(
          headers: {
            'x-api-key': Env.anthropicApiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          // L'API peut prendre 3-10s sur Haiku 4.5 selon la taille image.
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'model': _model,
          'max_tokens': 500,
          'system': _systemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mediaType,
                    'data': encoded,
                  },
                },
                {
                  'type': 'text',
                  'text':
                      "Identifie l'espèce sur cette photo selon le schéma JSON.",
                },
              ],
            },
          ],
        },
      );

      final content = response.data?['content'] as List?;
      if (content == null || content.isEmpty) return null;
      final textBlock = content.firstWhere(
        (c) => (c as Map<String, dynamic>)['type'] == 'text',
        orElse: () => null,
      );
      if (textBlock == null) return null;
      final text = (textBlock as Map<String, dynamic>)['text'] as String?;
      if (text == null) return null;

      final json = _extractJson(text);
      if (json == null) {
        developer.log(
          'Could not parse JSON from Claude response: $text',
          name: 'species_id',
        );
        return null;
      }
      return SpeciesIdentification.fromJson(json);
    } on DioException catch (e) {
      developer.log(
        'Dio error during identification: ${e.message} (${e.response?.statusCode})',
        name: 'species_id',
      );
      return null;
    } catch (e) {
      developer.log('Unexpected error during identification: $e',
          name: 'species_id');
      return null;
    }
  }

  String _detectMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Strip d'éventuels marqueurs markdown ```json ... ``` autour du JSON.
  Map<String, dynamic>? _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline != -1) {
        text = text.substring(firstNewline + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}

final speciesIdentificationServiceProvider =
    Provider<SpeciesIdentificationService>((ref) {
  return SpeciesIdentificationService(Dio());
});

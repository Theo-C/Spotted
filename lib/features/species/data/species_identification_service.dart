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
Tu es un expert naturaliste français spécialisé dans la faune sauvage européenne
(oiseaux, mammifères, reptiles, chiroptères).

# Méthode d'identification

Pour chaque photo, raisonne étape par étape AVANT de conclure :
1. **Taille relative** estimée (par rapport à des objets ou autres animaux visibles)
2. **Silhouette globale** (proportions, attitude, pose)
3. **Bec / museau / face** (forme, couleur, taille relative)
4. **Plumage / pelage** (couleurs, motifs, contrastes)
5. **Queue / arrière-train** (forme, longueur)
6. **Habitat / contexte** (forêt, eau, ciel, prairie, milieu humain)
7. Élimine d'abord les espèces clairement incompatibles
8. Compare les espèces restantes selon leurs **critères diagnostiques**

# Cas de confusion classiques en France (à connaître)

- **Grand Corbeau (Corvus corax)** vs **Corbeau freux (Corvus frugilegus)** vs **Corneille noire (Corvus corone)** :
  - Grand Corbeau : très grand, bec massif, queue **cunéiforme** (forme de losange), faciès uniforme noir, vol planant majestueux
  - Corbeau freux : plumage à reflets violets, **face nue gris-blanchâtre adulte**, bec plus pointu, vit en colonies
  - Corneille noire : taille moyenne, bec moins massif, queue carrée, face entièrement emplumée, plus solitaire
- **Buse variable** vs **Bondrée apivore** : Bondrée a queue plus longue avec barres distinctes, tête plus petite et "pigeonneau"
- **Chouette hulotte** vs **Chouette effraie** : Effraie a face en cœur blanche, Hulotte a tête arrondie marbrée
- **Pic épeiche** vs **Pic mar** : Mar a calotte rouge entière (mâle ET femelle), pas de moustache fermée
- **Faucon crécerelle** vs **Faucon hobereau** : Hobereau plus sombre, faucille plus marquée, "moustaches" très contrastées
- **Mésange charbonnière** (très commune) vs **Mésange bleue** (très commune) : tête noire vs tête bleue
- **Étourneau sansonnet** (très commun, exclu de Spotted) vs **Merle noir** (très commun, exclu) : étourneau plus pétillant, vol direct en groupe
- **Aigrette garzette** vs **Grande aigrette** : Garzette plus petite, **pieds jaunes** sur pattes noires

# Format de réponse

Tu réponds UNIQUEMENT en JSON valide, sans texte hors-JSON, sans bloc markdown,
suivant EXACTEMENT ce schéma :

{
  "detected": true|false,
  "candidates": [
    {
      "common_name": "Nom français standard",
      "scientific_name": "Nom binominal latin",
      "category_key": "birds" | "mammals" | "reptiles" | "bats",
      "rarity_key": "common" | "rare" | "epic" | "legendary",
      "confidence": 0.0..1.0
    },
    ... (1 à 3 candidats, classés par confiance décroissante)
  ],
  "rationale": "Phrase courte (max 30 mots) qui pointe les critères diagnostiques observés"
}

# Règles importantes

- **Toujours proposer 2-3 candidats** si tu as un doute, même léger. Préfère 3 candidats avec scores honnêtes à 1 candidat avec score gonflé.
- **Sois prudent sur la confiance** : 0.9+ uniquement si l'identification est sans ambiguïté. 0.5-0.7 si tu hésites entre plusieurs espèces. 0.3-0.5 si très incertain.
- Les confidences ne doivent PAS forcément sommer à 1.0 — elles reflètent ta confiance individuelle dans chaque hypothèse.
- Si la photo ne montre pas un animal sauvage identifiable (paysage, plante, chat/chien, photo floue, espèce hors d'Europe), renvoie `"detected": false` avec `"candidates": []` et explique dans `rationale`.

# Conventions raretés (en France métropolitaine)

- **common** : courante, visible toute l'année (buse variable, héron cendré, pic épeiche)
- **rare** : localisée ou en déclin (épervier, effraie, martin-pêcheur)
- **epic** : remarquable, à certaines saisons/lieux (pèlerin, huppe, chevêche)
- **legendary** : très discrète, limite d'aire, passage occasionnel (balbuzard, butor, grand-duc)
''';

  /// Identifie l'espèce sur [photo].
  ///
  /// [curatedSpecies] : liste optionnelle des espèces curées pour le territoire
  /// de la photo. Permet à l'IA de privilégier les espèces déjà connues du
  /// catalogue (gain de précision important — élimine les faux positifs hors
  /// répartition).
  ///
  /// [regionName] : nom du département/région (ex: "Oise", "Aisne") déduit
  /// du reverse-geocoding. Donne au modèle un contexte biogéographique.
  ///
  /// Renvoie null en cas d'erreur (réseau, parsing). L'app continue alors
  /// en mode manuel.
  Future<SpeciesIdentification?> identifyFromFile(
    File photo, {
    List<({String commonName, String scientificName})>? curatedSpecies,
    String? regionName,
  }) async {
    try {
      final bytes = await photo.readAsBytes();
      final encoded = base64Encode(bytes);
      final mediaType = _detectMediaType(photo.path);
      final userText = _buildUserPrompt(
        curatedSpecies: curatedSpecies,
        regionName: regionName,
      );

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
          // Plus de tokens pour permettre 3 candidats + rationale détaillée.
          'max_tokens': 800,
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
                  'text': userText,
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

  String _buildUserPrompt({
    List<({String commonName, String scientificName})>? curatedSpecies,
    String? regionName,
  }) {
    final buf = StringBuffer(
      "Identifie l'espèce sur cette photo en suivant la méthode et le format JSON.",
    );
    if (regionName != null && regionName.isNotEmpty) {
      buf.write(
        '\n\nContexte : photo prise dans le département **$regionName**, en France métropolitaine.',
      );
    }
    if (curatedSpecies != null && curatedSpecies.isNotEmpty) {
      buf.write(
        '\n\nVoici les espèces curées pour ce territoire (sur lesquelles l\'utilisateur a déjà une fiche dans son carnet) :',
      );
      for (final s in curatedSpecies) {
        buf.write('\n- ${s.commonName} *(${s.scientificName})*');
      }
      buf.write(
        '\n\nPrivilégie ces espèces si l\'identification visuelle le permet. '
        'Tu peux proposer une espèce hors liste UNIQUEMENT si la photo correspond '
        'clairement à autre chose ; mentionne-le alors dans le rationale.',
      );
    }
    return buf.toString();
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

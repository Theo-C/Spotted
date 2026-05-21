import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/env.dart';
import '../domain/species_identification.dart';

/// Identifie une espèce depuis une photo via Claude Vision (Anthropic API).
///
/// Modèle : Sonnet 4.6 avec **extended thinking** (budget 4000 tokens). Le
/// modèle déroule explicitement la chaîne diagnostique avant de conclure, ce
/// qui aide beaucoup sur les confusions fines (Grand Corbeau / Corbeau freux,
/// Buse variable / Bondrée apivore, etc. — cf. system prompt).
///
/// Coût indicatif : ~0.015 $/photo (input image + ~4800 tokens output dont
/// thinking). Pour 2 users à ~10 obs/jour ≈ 10-15 $/mois.
///
/// ⚠️ La clé API est embarquée dans l'APK (`.env` est asset Flutter). Pour un
/// déploiement public, proxifier via une edge function Supabase.
/// Snapshot du dernier appel d'identification IA — sert au diagnostic
/// "pourquoi l'IA m'a sorti ce truc ?". Stocké en mémoire (perdu au restart),
/// accessible via [lastAiCallProvider] et l'écran de debug du profil.
class AiCallSnapshot {
  const AiCallSnapshot({
    required this.timestamp,
    required this.model,
    required this.userPrompt,
    required this.rawResponse,
    required this.parsed,
    required this.durationMs,
    this.error,
  });

  final DateTime timestamp;
  final String model;
  final String userPrompt;
  final String rawResponse;
  final SpeciesIdentification? parsed;
  final int durationMs;
  final String? error;
}

class SpeciesIdentificationService {
  SpeciesIdentificationService(this._dio);

  final Dio _dio;

  static const _model = 'claude-sonnet-4-6';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  /// Dernier appel effectué (succès OU erreur). Lu par l'écran de debug.
  AiCallSnapshot? _lastCall;
  AiCallSnapshot? get lastCall => _lastCall;
  static const String systemPrompt = _systemPrompt;

  // Budget de raisonnement avant la réponse finale. 4000 tokens permettent à
  // Sonnet de dérouler intégralement la chaîne diagnostique (taille →
  // silhouette → bec → plumage → habitat → élimination → comparaison). Testé
  // à 2000 : trop court, le modèle se plantait sur des cas qu'il résolvait
  // bien à 4000. Le coût supplémentaire vaut la précision.
  static const _thinkingBudgetTokens = 4000;

  static const _systemPrompt = '''
Tu es un expert naturaliste de référence, spécialiste de la faune sauvage à
l'échelle mondiale (oiseaux, mammifères, reptiles, chiroptères), avec une
connaissance approfondie de l'Europe, des DOM-TOM français et des
archipels macaronésiens (Canaries, Açores, Madère).

# Importance du contexte géographique

Si un lieu est précisé dans le message utilisateur (commune, région, pays),
utilise-le comme **filtre prioritaire** AVANT l'analyse visuelle :

- Privilégie fortement les espèces dont l'aire de répartition couvre le lieu indiqué.
- Sur une île ou un territoire à fort taux d'endémisme (Canaries, La Réunion,
  Madagascar, Galapagos, Nouvelle-Calédonie...), donne un poids **majeur** aux
  espèces endémiques ou caractéristiques du lieu, même si visuellement proches
  d'espèces continentales.
- Écarte (ou note avec confiance basse) les espèces clairement hors aire de
  répartition, sauf si la photo montre des critères diagnostiques sans ambiguïté.
- Exemple-type : sur l'**île de La Palma (Canaries)**, le seul grand corvidé
  présent est le **Grand Corbeau (Corvus corax)** — proposer du Corbeau freux
  ou de la Corneille noire serait incohérent avec la géographie.

# Méthode d'identification

Une fois le filtre géographique appliqué, pour chaque photo, raisonne étape par
étape AVANT de conclure :
1. **Taille relative** estimée (par rapport à des objets ou autres animaux visibles)
2. **Silhouette globale** (proportions, attitude, pose)
3. **Bec / museau / face** (forme, couleur, taille relative)
4. **Plumage / pelage** (couleurs, motifs, contrastes)
5. **Queue / arrière-train** (forme, longueur)
6. **Habitat / contexte** (forêt, eau, ciel, prairie, milieu humain)
7. Élimine d'abord les espèces clairement incompatibles (visuel + géographie)
8. Compare les espèces restantes selon leurs **critères diagnostiques**

# Cas de confusion classiques en France métropolitaine (à connaître)

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
  /// répartition). Aujourd'hui rempli uniquement quand la photo est dans l'Oise.
  ///
  /// [place], [regionName], [country] : tous trois issus du reverse-geocoding
  /// Mapbox. On les passe au modèle pour qu'il applique un filtre biogéographique
  /// (cf. system prompt — endémismes, aire de répartition, etc.). Tous optionnels
  /// car une photo peut être sans GPS.
  ///
  /// Renvoie null en cas d'erreur (réseau, parsing). L'app continue alors
  /// en mode manuel.
  Future<SpeciesIdentification?> identifyFromFile(
    File photo, {
    List<({String commonName, String scientificName})>? curatedSpecies,
    String? place,
    String? regionName,
    String? country,
  }) async {
    final stopwatch = Stopwatch()..start();
    final userText = _buildUserPrompt(
      curatedSpecies: curatedSpecies,
      place: place,
      regionName: regionName,
      country: country,
    );
    try {
      final bytes = await _compressForVision(photo);
      if (bytes == null) {
        _lastCall = AiCallSnapshot(
          timestamp: DateTime.now(),
          model: _model,
          userPrompt: userText,
          rawResponse: '',
          parsed: null,
          durationMs: stopwatch.elapsedMilliseconds,
          error: 'Compression image échouée',
        );
        return null;
      }
      final encoded = base64Encode(bytes);
      // Après compression on est toujours en JPEG (cf. _compressForVision).
      const mediaType = 'image/jpeg';

      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        options: Options(
          headers: {
            'x-api-key': Env.anthropicApiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          // Sonnet 4.6 + extended thinking : compte 10-25s typiques selon la
          // taille de l'image et la complexité du raisonnement.
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'model': _model,
          // max_tokens DOIT être > thinking.budget_tokens. On laisse 1200 tokens
          // au-dessus du budget pour les blocks "text" (rationale + JSON candidats).
          'max_tokens': _thinkingBudgetTokens + 1200,
          'thinking': {
            'type': 'enabled',
            'budget_tokens': _thinkingBudgetTokens,
          },
          // Format array + cache_control ephemeral : Anthropic met le system
          // en cache pendant 5 min (TTL). Après le 1er call, ces ~3000 tokens
          // sont facturés à 10% de leur prix normal — gros gain quand on
          // identifie plusieurs photos d'affilée.
          'system': [
            {
              'type': 'text',
              'text': _systemPrompt,
              'cache_control': {'type': 'ephemeral'},
            },
          ],
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
      final textBlock = content?.firstWhere(
        (c) => (c as Map<String, dynamic>)['type'] == 'text',
        orElse: () => null,
      ) as Map<String, dynamic>?;
      final text = (textBlock?['text'] as String?) ?? '';

      SpeciesIdentification? parsed;
      String? error;
      if (text.isEmpty) {
        error = 'Réponse vide (pas de block texte)';
      } else {
        final json = _extractJson(text);
        if (json == null) {
          error = 'JSON non parsable depuis la réponse';
          developer.log(
            'Could not parse JSON from Claude response: $text',
            name: 'species_id',
          );
        } else {
          try {
            parsed = SpeciesIdentification.fromJson(json);
          } catch (e) {
            error = 'Schéma JSON inattendu : $e';
          }
        }
      }
      _lastCall = AiCallSnapshot(
        timestamp: DateTime.now(),
        model: _model,
        userPrompt: userText,
        rawResponse: text,
        parsed: parsed,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      return parsed;
    } on DioException catch (e) {
      final msg =
          'Dio error : ${e.message} (HTTP ${e.response?.statusCode}) ${e.response?.data}';
      developer.log(msg, name: 'species_id');
      _lastCall = AiCallSnapshot(
        timestamp: DateTime.now(),
        model: _model,
        userPrompt: userText,
        rawResponse: e.response?.data?.toString() ?? '',
        parsed: null,
        durationMs: stopwatch.elapsedMilliseconds,
        error: msg,
      );
      return null;
    } catch (e) {
      developer.log('Unexpected error during identification: $e',
          name: 'species_id');
      _lastCall = AiCallSnapshot(
        timestamp: DateTime.now(),
        model: _model,
        userPrompt: userText,
        rawResponse: '',
        parsed: null,
        durationMs: stopwatch.elapsedMilliseconds,
        error: 'Erreur inattendue : $e',
      );
      return null;
    }
  }

  String _buildUserPrompt({
    List<({String commonName, String scientificName})>? curatedSpecies,
    String? place,
    String? regionName,
    String? country,
  }) {
    final buf = StringBuffer(
      "Identifie l'espèce sur cette photo en suivant la méthode et le format JSON.",
    );

    final parts = <String>[
      if (place != null && place.isNotEmpty) place,
      if (regionName != null && regionName.isNotEmpty) regionName,
      if (country != null && country.isNotEmpty) country,
    ];
    if (parts.isNotEmpty) {
      buf.write(
        '\n\n**Contexte géographique** : photo prise à ${parts.join(', ')}. '
        "Applique le filtre biogéographique (cf. tes consignes système) : "
        "privilégie les espèces caractéristiques du lieu, pondère les endémismes, "
        "écarte celles clairement hors aire de répartition.",
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

  /// Compresse la photo avant envoi à l'API Vision Anthropic.
  ///
  /// Pourquoi : l'API plafonne à 5 MB par image en base64, alors qu'une photo
  /// moderne fait souvent 8-12 MB. On redimensionne à 1024px max sur le côté
  /// le plus long (~1.4k tokens d'image — assez de détail pour la diagnose
  /// ornithologique sans cramer des tokens vu qu'on est facturé sur la
  /// dimension), et on ré-encode en JPEG quality 85. Résultat typique :
  /// 200-500 KB. Convertit aussi HEIC → JPEG côté Android/iOS natif, ce qui
  /// simplifie le media_type côté API.
  Future<Uint8List?> _compressForVision(File photo) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        photo.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      developer.log('Image compression failed: $e', name: 'species_id');
      return null;
    }
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

/// Provider du dernier snapshot d'appel IA. Re-évalué à chaque rebuild
/// — l'écran de debug du profil l'utilise pour afficher prompt + réponse.
/// Renvoie null tant qu'aucun appel n'a été fait pendant cette session.
final lastAiCallProvider = Provider<AiCallSnapshot?>((ref) {
  return ref.watch(speciesIdentificationServiceProvider).lastCall;
});

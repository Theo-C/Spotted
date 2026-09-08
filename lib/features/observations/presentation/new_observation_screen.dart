import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/services/location_service.dart';
import '../../../shared/models/category.dart' as model;
import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/models/species_reference.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/data/daily_species_provider.dart';
import '../../gamification/data/gamification_state_provider.dart';
import '../../gamification/domain/points.dart';
import '../../species/data/species_identification_service.dart';
import '../../species/data/species_reference_repository.dart';
import '../../species/data/species_repository.dart';
import '../../species/data/species_with_rarity_provider.dart';
import '../../species/domain/species_identification.dart';
import '../../species/presentation/multi_zone_selector.dart';
import '../../species/presentation/species_photo_picker.dart';
import '../../species/presentation/species_reference_autocomplete.dart';
import '../../territories/data/category_repository.dart';
import '../../territories/data/geocoding_service.dart';
import '../../territories/data/territory_progress_provider.dart';
import '../../territories/data/zone_repository.dart';
import '../data/observation_repository.dart';
import '../data/observations_for_map_provider.dart';
import '../data/observed_species_provider.dart';
import '../data/photo_picker_service.dart';
import '../data/photo_upload_service.dart';

/// Identification IA via Claude Haiku 4.5 + contexte géo enrichi.
/// Si Haiku rate à nouveau les confusions fines (Grand Corbeau vs Corbeau freux
/// dans l'Oise, etc.), basculer le modèle dans species_identification_service
/// vers claude-sonnet-4-6 (~3x plus cher mais nettement plus précis).
const _iaIdentificationEnabled = true;

/// Écran de saisie d'une nouvelle observation.
/// Si [preselectedSpeciesId] non nul, l'espèce est verrouillée (cas
/// "Je l'ai vue !" depuis la fiche). Sinon, l'utilisateur la choisit.
class NewObservationScreen extends ConsumerStatefulWidget {
  const NewObservationScreen({super.key, this.preselectedSpeciesId});

  final String? preselectedSpeciesId;

  @override
  ConsumerState<NewObservationScreen> createState() =>
      _NewObservationScreenState();
}

class _NewObservationScreenState
    extends ConsumerState<NewObservationScreen> {
  PickedPhoto? _photo;
  DateTime _observedAt = DateTime.now();
  double? _lat;
  double? _lng;
  String? _selectedSpeciesId;
  bool _submitting = false;
  String? _error;

  // Identification IA — lancée en arrière-plan au pick photo.
  SpeciesIdentification? _identification;
  bool _identifying = false;
  bool _suggestionDismissed = false;

  /// Candidat IA accepté par l'user — sert à highlight visuellement le bon
  /// dans la suggestion card (sinon rank 1 reste highlighted en permanence,
  /// ce qui donne l'illusion que c'est lui le choix de l'user).
  /// Null si rien d'accepté (initial ou reset après nouvelle photo).
  SpeciesCandidate? _acceptedCandidate;

  // -----------------------------------------------------------
  // Photo-first : résolution territoriale dès que la position est connue,
  // au lieu d'attendre le submit. Évite le dialog rareté surprise au save.
  // -----------------------------------------------------------

  /// État de la résolution de zone — null tant qu'aucune position n'a été
  /// fournie (ni EXIF GPS, ni map picker manuel).
  _ZoneResolution? _zoneResolution;

  /// Rareté de l'espèce courante dans la zone détectée, lue depuis
  /// species_zones. Null si l'espèce n'est pas encore curée pour cette zone
  /// (cas où on demande à l'user de choisir inline) OU si la résolution n'a
  /// pas encore tourné.
  Rarity? _speciesLocalRarity;

  /// Choix utilisateur via le sélecteur de rareté inline. Utilisé quand
  /// _speciesLocalRarity est null et que l'user a tapé un des 4 boutons.
  /// À l'insertion, on crée la ligne species_zones manquante avec cette valeur.
  Rarity? _userPickedRarity;

  /// True pendant l'aller-retour Supabase pour récupérer la rareté locale.
  bool _resolvingRarity = false;

  /// Tokens monotones pour éviter qu'une résolution lente ne sur-écrive
  /// une résolution plus récente (course classique : photo A → photo B
  /// dans 200 ms, la réponse pour A arrive après B → fausse l'UI).
  int _zoneToken = 0;
  int _rarityToken = 0;

  @override
  void initState() {
    super.initState();
    _selectedSpeciesId = widget.preselectedSpeciesId;
  }

  // -----------------------------------------------------------
  // Résolution territoriale (photo-first)
  // -----------------------------------------------------------

  /// Lance la résolution de zone à partir de (_lat, _lng). Appelé après
  /// chaque changement de position (photo importée, map picker bougé).
  /// Idempotent — un appel concurrent invalide le précédent via _zoneToken.
  Future<void> _resolveZone() async {
    final myToken = ++_zoneToken;
    if (_lat == null || _lng == null) {
      setState(() {
        _zoneResolution = null;
      });
      // La rareté dépend de la zone : on réinvalide aussi.
      await _resolveSpeciesRarity();
      return;
    }
    setState(() {
      _zoneResolution = const _ZoneResolving();
    });

    try {
      final lat = _lat!;
      final lng = _lng!;
      final geocoding = await ref
          .read(geocodingServiceProvider)
          .reverseGeocode(lat: lat, lng: lng);
      if (myToken != _zoneToken || !mounted) return;

      // 1. Geocoding totalement raté.
      if (geocoding == null ||
          (geocoding.country == null &&
              geocoding.region == null &&
              geocoding.place == null)) {
        setState(() {
          _zoneResolution = const _ZoneError(
            'Impossible de déterminer le lieu. Vérifie ta connexion ou repositionne le marqueur.',
          );
        });
        await _resolveSpeciesRarity();
        return;
      }

      // 2. Hors France.
      final country = geocoding.country;
      if (country != null && country != 'France') {
        setState(() {
          _zoneResolution = _ZoneError(
            'Position en « $country ». Seules les zones France curées sont supportées.',
          );
        });
        await _resolveSpeciesRarity();
        return;
      }

      // 3. Lookup de la zone curée par nom de région (= département en v6).
      final zones = await ref.read(zoneRepositoryProvider).getAll();
      if (myToken != _zoneToken || !mounted) return;
      final region = geocoding.region;
      final matched = zones.cast<Zone?>().firstWhere(
            (z) => z!.name == region,
            orElse: () => null,
          );
      if (matched == null) {
        setState(() {
          _zoneResolution = _ZoneError(
            'Position en « ${region ?? 'région inconnue'} ». '
            'Zones curées : ${zones.map((z) => z.name).join(', ')}. '
            'Repositionne le marqueur.',
          );
        });
        await _resolveSpeciesRarity();
        return;
      }
      setState(() {
        _zoneResolution = _ZoneResolved(
          zone: matched,
          placeLabel: geocoding.displayName,
        );
      });
      await _resolveSpeciesRarity();
    } catch (e) {
      if (myToken == _zoneToken && mounted) {
        setState(() {
          _zoneResolution = _ZoneError('Erreur de résolution : $e');
        });
      }
    }
  }

  /// Lance la résolution de rareté locale (species_zones lookup) dès qu'une
  /// espèce ET une zone résolue OK sont en place. Si la paire n'est pas
  /// curée, on bascule l'UI en mode "choisis la rareté localement" via le
  /// sélecteur inline.
  Future<void> _resolveSpeciesRarity() async {
    final myToken = ++_rarityToken;
    final zone = _zoneResolution is _ZoneResolved
        ? (_zoneResolution as _ZoneResolved).zone
        : null;
    if (zone == null || _selectedSpeciesId == null) {
      setState(() {
        _speciesLocalRarity = null;
        _userPickedRarity = null;
        _resolvingRarity = false;
      });
      return;
    }
    setState(() {
      _resolvingRarity = true;
      _speciesLocalRarity = null;
      _userPickedRarity = null;
    });
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('species_zones')
          .select('rarity')
          .eq('species_id', _selectedSpeciesId!)
          .eq('zone_id', zone.id)
          .maybeSingle();
      if (myToken != _rarityToken || !mounted) return;
      if (row != null) {
        setState(() {
          _speciesLocalRarity = Rarity.values
              .firstWhere((r) => r.name == (row['rarity'] as String));
          _resolvingRarity = false;
        });
      } else {
        // Pré-remplit le picker avec la rareté trouvée dans une autre zone
        // si dispo, sinon commun. L'user peut changer librement.
        final any = await ref
            .read(supabaseClientProvider)
            .from('species_zones')
            .select('rarity')
            .eq('species_id', _selectedSpeciesId!)
            .limit(1)
            .maybeSingle();
        if (myToken != _rarityToken || !mounted) return;
        final hint = any != null
            ? Rarity.values
                .firstWhere((r) => r.name == (any['rarity'] as String))
            : Rarity.common;
        setState(() {
          _resolvingRarity = false;
          _userPickedRarity = hint;
        });
      }
    } catch (e) {
      if (myToken == _rarityToken && mounted) {
        setState(() => _resolvingRarity = false);
      }
    }
  }

  /// Rareté effective utilisée au submit : la lecture BDD prime, sinon le
  /// choix manuel de l'user. Null si rien n'est résolu — bloque le submit.
  Rarity? get _effectiveRarity => _speciesLocalRarity ?? _userPickedRarity;

  /// True si on attend de l'user qu'il choisisse une rareté dans le
  /// sélecteur inline (zone OK, espèce choisie, mais paire pas en BDD).
  bool get _needsRarityPicker =>
      _zoneResolution is _ZoneResolved &&
      _selectedSpeciesId != null &&
      !_resolvingRarity &&
      _speciesLocalRarity == null;

  Future<void> _pickPhoto() async {
    final picked =
        await ref.read(photoPickerServiceProvider).pickFromGallery();
    if (picked == null) return;
    setState(() {
      _photo = picked;
      if (picked.takenAt != null) _observedAt = picked.takenAt!;
      // Toujours réassigner (même null) : sinon, après un 1er pick avec GPS
      // suivi d'un pick sans GPS, les coords du 1er pick survivraient et
      // le geocoding renverrait un faux lieu.
      _lat = picked.latitude;
      _lng = picked.longitude;
      _identification = null;
      _suggestionDismissed = false;
      _identifying = false;
      _acceptedCandidate = null;
    });
    // Photo-first : on lance la résolution territoriale tout de suite (au lieu
    // d'attendre le submit). Si la photo a un EXIF GPS, on saura immédiatement
    // si on est dans une zone curée ; sinon le banner dira "place le point
    // sur la carte" et le user bouge la mini-carte.
    unawaited(_resolveZone());
    // L'IA n'est plus auto-lancée au pick — l'user clique sur le bouton
    // "Identifier avec l'IA" s'il veut une suggestion (cf. _triggerIdentification).
    // Ça évite la facture quand on connaît déjà l'espèce ou qu'on est offline.
  }

  /// Déclenche manuellement l'identification IA sur la photo courante.
  /// Appelé par le bouton "Identifier avec l'IA" qui apparaît tant qu'aucune
  /// identification n'a tourné pour cette photo.
  void _triggerIdentification() {
    if (_photo == null || _identifying || _identification != null) return;
    setState(() {
      _identifying = true;
      _suggestionDismissed = false;
    });
    unawaited(_runIdentification(_photo!.file));
  }

  Future<void> _runIdentification(File file) async {
    // Contexte conditionnel selon les coords EXIF :
    //   - photo avec GPS dans une zone curée  → place + region + country + liste curée
    //   - photo avec GPS hors zone curée      → place + region + country (filtre biogéo IA)
    //   - photo sans GPS                      → aucun contexte (mieux que des biais faux)
    String? place;
    String? regionName;
    String? country;
    List<({String commonName, String scientificName})>? curated;

    if (_lat != null && _lng != null) {
      final geocoding = await ref
          .read(geocodingServiceProvider)
          .reverseGeocode(lat: _lat!, lng: _lng!);
      place = geocoding?.place;
      regionName = geocoding?.region;
      country = geocoding?.country;
      if (regionName != null) {
        final zones = await ref.read(zoneRepositoryProvider).getAll();
        final detectedZone = zones.cast<Zone?>().firstWhere(
              (z) => z!.name == regionName,
              orElse: () => null,
            );
        if (detectedZone != null) {
          final allSpecies =
              await ref.read(_zoneSpeciesProvider(detectedZone.id).future);
          curated = allSpecies
              .map((s) => (
                    commonName: s.species.commonName,
                    scientificName: s.species.scientificName,
                  ))
              .toList();
        }
      }
    }

    final result = await ref
        .read(speciesIdentificationServiceProvider)
        .identifyFromFile(
          file,
          curatedSpecies: curated,
          place: place,
          regionName: regionName,
          country: country,
        );
    if (!mounted) return;
    setState(() {
      _identification = result;
      _identifying = false;
    });
  }

  /// Zone détectée pour la photo/position courante, ou null si l'user n'a pas
  /// encore positionné. Utilisée pour pré-cocher le bon territoire dans le
  /// dialog d'ajout d'espèce et pour rechercher les doublons dans la bonne zone.
  Zone? get _detectedZone => _zoneResolution is _ZoneResolved
      ? (_zoneResolution as _ZoneResolved).zone
      : null;

  Future<void> _acceptCandidate(SpeciesCandidate candidate) async {
    if (candidate.scientificName.isEmpty) return;
    // Marque visuellement le candidat choisi dans la suggestion card.
    setState(() => _acceptedCandidate = candidate);
    // Recherche GLOBALE par nom scientifique (toutes zones confondues).
    // L'ancienne version cherchait dans _zoneSpeciesProvider(zone), ce qui
    // ratait deux cas :
    //   1. Espèce créée avec une zone différente (pas liée à la zone courante).
    //   2. Cache _zoneSpeciesProvider pas encore refresh après un ajout récent.
    // En interrogeant directement species, on est insensible à species_zones :
    // si l'espèce existe sous ce nom scientifique, on la réutilise. Le flow
    // photo-first gère ensuite l'éventuelle absence de species_zones pour la
    // zone courante via le sélecteur de rareté inline.
    final searchName = candidate.scientificName.trim();
    final row = await ref
        .read(supabaseClientProvider)
        .from('species')
        .select('id')
        .ilike('scientific_name', searchName)
        .limit(1)
        .maybeSingle();
    if (!mounted) return;
    final existingId = row?['id'] as String?;

    if (existingId != null) {
      setState(() => _selectedSpeciesId = existingId);
      unawaited(_resolveSpeciesRarity());
    } else {
      // Espèce vraiment nouvelle (pas en BDD) → dialog d'ajout in-place.
      final newId = await showDialog<String>(
        context: context,
        builder: (_) => _AddSpeciesDialog(
          candidate: candidate,
          initialZoneId: _detectedZone?.id,
        ),
      );
      if (newId != null && mounted) {
        ref.invalidate(_zoneSpeciesProvider);
        ref.invalidate(speciesByCategoryInZoneProvider);
        ref.invalidate(categoriesWithProgressProvider);
        setState(() => _selectedSpeciesId = newId);
        unawaited(_resolveSpeciesRarity());
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _observedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _observedAt = picked);
  }

  Future<void> _pickSpecies() async {
    // Le picker liste les espèces curées de la zone détectée. Si pas de
    // zone (user pas encore positionné), on retombe sur Oise pour ne pas
    // ouvrir un picker vide ; mais l'idéal est que l'user positionne d'abord.
    final Zone pickerZone =
        _detectedZone ?? await ref.read(oiseZoneProvider.future);
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SpeciesPickerSheet(zoneId: pickerZone.id),
    );
    if (result != null) {
      setState(() {
        _selectedSpeciesId = result;
        // Choix via le picker manuel = on désélectionne tout candidat IA.
        _acceptedCandidate = null;
      });
      unawaited(_resolveSpeciesRarity());
    }
  }

  Future<void> _submit() async {
    // Validations basées sur l'état pré-résolu (photo-first). Pas de surprise
    // au save : zone et rareté sont déjà connues à ce stade.
    if (_zoneResolution == null) {
      setState(() => _error =
          'Ajoute une photo géolocalisée ou place le point sur la carte.');
      return;
    }
    if (_zoneResolution is _ZoneResolving) {
      setState(() => _error = 'Résolution territoriale en cours…');
      return;
    }
    if (_zoneResolution is _ZoneError) {
      setState(() => _error = (_zoneResolution as _ZoneError).message);
      return;
    }
    final detectedZone = (_zoneResolution as _ZoneResolved).zone;

    if (_selectedSpeciesId == null) {
      setState(() => _error = 'Choisis une espèce.');
      return;
    }
    if (_resolvingRarity) {
      setState(() => _error = 'Lecture de la rareté en cours…');
      return;
    }
    final rarity = _effectiveRarity;
    if (rarity == null) {
      setState(() => _error = 'Choisis la rareté locale de cette espèce.');
      return;
    }

    final observerId = ref.read(currentAuthUserProvider)?.id;
    if (observerId == null) {
      setState(() => _error = 'Pas d\'utilisateur connecté.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final speciesId = _selectedSpeciesId!;
      final lat = _lat!;
      final lng = _lng!;

      // Si l'user a choisi la rareté inline (paire species_zones absente),
      // on crée la ligne pour que les futures obs n'aient plus à le faire
      // et que l'espèce apparaisse dans la liste de la zone.
      if (_speciesLocalRarity == null && _userPickedRarity != null) {
        await client.from('species_zones').insert({
          'species_id': speciesId,
          'zone_id': detectedZone.id,
          'rarity': _userPickedRarity!.name,
        });
        ref.invalidate(speciesByCategoryInZoneProvider);
      }

      // is_first_for_user (côté client — le trigger serveur fait l'autorité)
      final existing = await client
          .from('observations')
          .select('id')
          .eq('user_id', observerId)
          .eq('species_id', speciesId)
          .limit(1);
      final isFirst = (existing as List).isEmpty;

      // Upload photo (si présente)
      String? photoUrl;
      if (_photo != null) {
        photoUrl =
            await ref.read(photoUploadServiceProvider).uploadObservationPhoto(
                  file: _photo!.file,
                  observerUserId: observerId,
                );
      }

      // Multiplicateur de série courante (1.0 si pas encore au palier J7).
      // Lu AVANT l'insertion : on récompense la série qui a amené ici, pas
      // celle qui inclura cette obs.
      final streak = ref.read(streakProvider);
      // Bonus x2 si l'espèce est celle du jour ET si l'obs est datée
      // d'aujourd'hui (pas un import de photo d'hier — le défi est
      // l'observation du jour, pas la validation du jour).
      final now = DateTime.now().toLocal();
      final obsLocal = _observedAt.toLocal();
      final isSameDay = obsLocal.year == now.year &&
          obsLocal.month == now.month &&
          obsLocal.day == now.day;
      final isDailySpecies =
          ref.read(isDailySpeciesProvider(speciesId)) && isSameDay;
      final pointsEarned = observationPoints(
        rarity: rarity,
        isFirst: isFirst,
        hasPhoto: photoUrl != null,
        isDailySpecies: isDailySpecies,
        streakMultiplier: streak.xpMultiplier,
      );

      await ref.read(observationRepositoryProvider).create(
            userId: observerId,
            speciesId: speciesId,
            zoneId: detectedZone.id,
            observedAt: _observedAt,
            latitude: lat,
            longitude: lng,
            photoUrl: photoUrl,
            photoExifData: _photo?.exif,
            pointsEarned: pointsEarned,
            wasDailySpecies: isDailySpecies,
          );

      // Rafraîchit les écrans qui dépendent de la BDD
      ref.invalidate(observedSpeciesIdsInZoneProvider);
      ref.invalidate(categoriesWithProgressProvider);
      ref.invalidate(zoneProgressProvider);
      ref.invalidate(allObservationsForMapProvider);
      ref.invalidate(accountTotalPointsProvider);
      ref.invalidate(accountLevelProvider);

      if (!mounted) return;
      await _showDiscoveryDialog(
        rarity: rarity,
        points: pointsEarned,
        isFirst: isFirst,
      );

      if (!mounted) return;
      context.pop();
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Erreur BDD : ${e.message}';
        });
      }
    } on StorageException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Erreur Storage : ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  Future<void> _showDiscoveryDialog({
    required Rarity rarity,
    required int points,
    required bool isFirst,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _DiscoveryDialog(
        rarity: rarity,
        points: points,
        isFirst: isFirst,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = _selectedSpeciesId == null
        ? const AsyncValue<Species?>.data(null)
        : ref.watch(_speciesByIdProvider(_selectedSpeciesId!));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nouvelle observation',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: forestGreen),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhotoSlot(photo: _photo, onTap: _pickPhoto),
            // Banner statut territorial — mis à jour dès qu'une position est
            // connue (EXIF photo ou map picker), et non plus seulement au submit.
            // AnimatedSize évite le "saut" visuel quand le banner passe de
            // "Résolution…" à "Compiègne, Oise" (hauteurs différentes).
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _ZoneStatusBanner(
                resolution: _zoneResolution,
                hasPhoto: _photo != null,
                photoHasGps: _photo?.hasGps ?? false,
              ),
            ),
            if (_photo != null &&
                _iaIdentificationEnabled &&
                widget.preselectedSpeciesId == null &&
                _identification == null &&
                !_identifying) ...[
              const SizedBox(height: 12),
              _IdentifyWithIaButton(onTap: _triggerIdentification),
            ],
            if (!_suggestionDismissed && (_identifying || _identification != null)) ...[
              const SizedBox(height: 12),
              _IaSuggestionCard(
                identifying: _identifying,
                identification: _identification,
                acceptedCandidate: _acceptedCandidate,
                onAcceptCandidate: _acceptCandidate,
                onDismiss: () => setState(() => _suggestionDismissed = true),
              ),
            ],
            const SizedBox(height: 20),
            const _Label('Date'),
            const SizedBox(height: 6),
            _ReadOnlyField(
              text: DateFormat('d MMMM yyyy', 'fr').format(_observedAt),
              icon: Icons.calendar_today,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            const _Label('Position'),
            const SizedBox(height: 6),
            _LocationTools(
              photo: _photo,
              onLocationPicked: (pos) {
                setState(() {
                  _lat = pos.lat;
                  _lng = pos.lng;
                });
                unawaited(_resolveZone());
              },
            ),
            const SizedBox(height: 8),
            _MiniMapPicker(
              lat: _lat ?? 49.41,
              lng: _lng ?? 2.82,
              onPositionChanged: (pos) {
                setState(() {
                  _lat = pos.lat;
                  _lng = pos.lng;
                });
                // Position changée → on relance la résolution territoriale
                // pour mettre à jour le banner et la rareté si besoin.
                unawaited(_resolveZone());
              },
            ),
            const SizedBox(height: 6),
            _CoordsField(lat: _lat, lng: _lng),
            const SizedBox(height: 16),
            const _Label('Espèce'),
            const SizedBox(height: 6),
            _SpeciesField(
              speciesAsync: speciesAsync,
              locked: widget.preselectedSpeciesId != null,
              onTap: widget.preselectedSpeciesId != null ? null : _pickSpecies,
            ),
            // Sélecteur de rareté inline — apparaît uniquement quand l'espèce
            // choisie n'a pas de ligne species_zones pour la zone détectée.
            // C'est là que le user pose le choix (vs ancien dialog au submit).
            // AnimatedSize pour lisser l'apparition (évite le saut de layout
            // quand la zone se résout).
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _needsRarityPicker
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _RarityPickerInline(
                        zoneName: (_zoneResolution as _ZoneResolved).zone.name,
                        selected: _userPickedRarity,
                        onSelected: (r) =>
                            setState(() => _userPickedRarity = r),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.karla(
                  color: const Color(0xFFFF5A5A),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: forestGreen,
                foregroundColor: surfaceBase,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: surfaceBase,
                      ),
                    )
                  : Text(
                      'AJOUTER AU CARNET',
                      style: GoogleFonts.karla(
                        fontSize: 13,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lookup d'une espèce par id (pour afficher le nom dans le form).
final _speciesByIdProvider =
    FutureProvider.family<Species, String>((ref, id) async {
  return ref.watch(speciesRepositoryProvider).getById(id);
});

/// Toutes les espèces présentes dans une zone, avec leur rareté.
/// Utilisé par le picker modal.
final _zoneSpeciesProvider =
    FutureProvider.family<List<({Species species, Rarity rarity})>, String>(
  (ref, zoneId) async {
    final client = ref.watch(supabaseClientProvider);
    final rows = await client
        .from('species')
        .select('*, species_zones!inner(rarity, zone_id)')
        .eq('species_zones.zone_id', zoneId)
        .order('common_name');
    return (rows as List).map((row) {
      final m = row as Map<String, dynamic>;
      final szList = m['species_zones'] as List;
      final rarityStr =
          (szList.first as Map<String, dynamic>)['rarity'] as String;
      final rarity = Rarity.values.firstWhere((r) => r.name == rarityStr);
      final speciesJson = Map<String, dynamic>.from(m)..remove('species_zones');
      return (species: Species.fromJson(speciesJson), rarity: rarity);
    }).toList();
  },
);

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.karla(
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
        color: textSecondary,
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.photo, required this.onTap});

  final PickedPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: photo == null ? const Color(0xFFC4A572) : forestGreen,
            width: 2,
          ),
          image: photo != null
              ? DecorationImage(
                  image: FileImage(photo!.file),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: Color(0xFFC4A572),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CHOISIR UNE PHOTO',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: terracotta,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "la date et le lieu seront lus dans l'EXIF",
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.text,
    required this.icon,
    this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8E0CE), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton "Identifier avec l'IA" affiché sous le slot photo tant que
/// l'utilisateur n'a pas déclenché l'identification. Permet de zapper l'appel
/// IA (et son coût ~0,02€) quand on connaît déjà l'espèce ou qu'on est offline.
class _IdentifyWithIaButton extends StatelessWidget {
  const _IdentifyWithIaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gold.withValues(alpha: 0.08),
                gold.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Identifier avec l'IA",
                      style: GoogleFonts.karla(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: forestGreen,
                      ),
                    ),
                    Text(
                      'Propose les espèces probables d\'après la photo',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: forestGreen, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _IaSuggestionCard extends StatelessWidget {
  const _IaSuggestionCard({
    required this.identifying,
    required this.identification,
    required this.acceptedCandidate,
    required this.onAcceptCandidate,
    required this.onDismiss,
  });

  final bool identifying;
  final SpeciesIdentification? identification;

  /// Candidat actuellement choisi par l'user — sert à marquer visuellement
  /// la sélection. Null = aucun choix encore, on highlight le rank 1 par
  /// défaut (recommandation IA).
  final SpeciesCandidate? acceptedCandidate;
  final void Function(SpeciesCandidate) onAcceptCandidate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (identifying) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: gold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Identification IA…',
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final id = identification;
    if (id == null) return const SizedBox.shrink();

    if (!id.detected || id.candidates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_off, color: textMuted, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                id.rationale.isNotEmpty
                    ? id.rationale
                    : "L'IA n'a pas pu identifier l'espèce.",
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: textMuted),
              onPressed: onDismiss,
              tooltip: 'Masquer',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gold.withValues(alpha: 0.08),
            gold.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: gold, size: 16),
              const SizedBox(width: 6),
              Text(
                'SUGGESTIONS IA',
                style: GoogleFonts.karla(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: textMuted),
                onPressed: onDismiss,
                tooltip: 'Masquer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (id.rationale.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              id.rationale,
              style: GoogleFonts.karla(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Index du candidat sélectionné par l'user. Si aucun n'a encore
          // été touché, on highlight le rank 1 par défaut (recommandation
          // initiale de l'IA, comme c'était le cas avant le fix).
          ...() {
            final selectedIdx = acceptedCandidate == null
                ? 0
                : id.candidates.indexWhere(
                    (c) => c.scientificName == acceptedCandidate!.scientificName,
                  );
            return [
              for (var i = 0; i < id.candidates.length; i++) ...[
                _CandidateRow(
                  candidate: id.candidates[i],
                  rank: i + 1,
                  isSelected: i == selectedIdx,
                  hasUserChoice: acceptedCandidate != null,
                  onTap: () => onAcceptCandidate(id.candidates[i]),
                ),
                if (i < id.candidates.length - 1)
                  const SizedBox(height: 6),
              ],
            ];
          }(),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.rank,
    required this.isSelected,
    required this.hasUserChoice,
    required this.onTap,
  });

  final SpeciesCandidate candidate;
  final int rank;

  /// True si c'est ce candidat qui doit être mis en évidence (= choix user
  /// si hasUserChoice, sinon rank 1 par défaut).
  final bool isSelected;

  /// True dès que l'user a fait un choix explicite — sert à différencier
  /// "highlight = recommandation IA initiale" et "highlight = j'ai cliqué".
  /// On affiche un check ✓ uniquement dans le second cas.
  final bool hasUserChoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = (candidate.confidence * 100).round();
    final isLow = candidate.confidence < 0.5;
    final showCheck = isSelected && hasUserChoice;
    return Material(
      color: isSelected ? surfaceBase : surfaceCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? (hasUserChoice ? forestGreen : gold)
                  : const Color(0xFFE8E0CE),
              width: isSelected ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (hasUserChoice ? forestGreen : gold)
                      : const Color(0xFFE8E0CE),
                ),
                child: Center(
                  child: showCheck
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: surfaceBase,
                        )
                      : Text(
                          '$rank',
                          style: GoogleFonts.karla(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? forestGreen : textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.commonName,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: forestGreen,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      candidate.scientificName,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: terracotta,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLow
                      ? terracotta.withValues(alpha: 0.15)
                      : forestGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pct %',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLow ? terracotta : forestGreen,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}


/// Dialog d'ajout d'une espèce au catalogue d'une zone.
/// Deux modes :
///   - Candidat IA fourni → nom et nom scientifique pré-remplis et figés ;
///     l'utilisateur ne choisit que catégorie + rareté (+ description/tips).
///   - Pas de candidat (saisie manuelle depuis le picker) → tous les champs
///     éditables. Cas d'une espèce vraiment nouvelle (jamais observée nulle
///     part) ; on demande tout pour qu'elle entre proprement dans le catalogue.
class _AddSpeciesDialog extends ConsumerStatefulWidget {
  const _AddSpeciesDialog({this.candidate, this.initialZoneId});

  final SpeciesCandidate? candidate;

  /// Zone à pré-cocher dans le sélecteur de territoires. En provenance de la
  /// position courante (EXIF photo ou map picker). Null = aucune position
  /// connue → on ne pré-coche rien, l'user doit explicitement choisir.
  final String? initialZoneId;

  @override
  ConsumerState<_AddSpeciesDialog> createState() => _AddSpeciesDialogState();
}

class _AddSpeciesDialogState extends ConsumerState<_AddSpeciesDialog> {
  late final TextEditingController _commonName;
  late final TextEditingController _scientificName;
  late final TextEditingController _description;
  late final TextEditingController _tips;
  String? _selectedCategoryId;
  late Rarity _selectedRarity;
  bool _submitting = false;
  String? _error;
  File? _pickedPhoto;

  /// Set des zone_id auxquels l'espèce sera liée à la création.
  /// Pré-coché sur la zone détectée si l'user est positionné, sinon vide
  /// (il devra cocher explicitement — pas de défaut Oise arbitraire).
  /// Modifiable via les chips FilterChip. Insert species_zones se fait pour
  /// chacune avec la même rareté.
  late final Set<String> _selectedZoneIds = widget.initialZoneId == null
      ? <String>{}
      : {widget.initialZoneId!};

  /// URL photo récupérée depuis species_reference (iNat-enriched).
  /// Pré-affichée dans le picker comme photo "existante" ; ré-utilisée
  /// directement à la création si l'user ne pick pas la sienne (pas
  /// d'upload, on garde l'URL iNat telle quelle).
  String? _existingPhotoUrl;

  /// Category key issu de species_reference (birds/mammals/...). Permet
  /// de pré-sélectionner la catégorie même quand on n'a pas de candidat IA.
  String? _refCategoryKey;

  /// True si on est en train de chercher dans la banque (UX loader).
  bool _refLoading = false;

  bool get _isManual => widget.candidate == null;

  Future<void> _pickPhoto() async {
    final picked =
        await ref.read(photoPickerServiceProvider).pickFromGallery();
    if (picked == null || !mounted) return;
    setState(() {
      _pickedPhoto = picked.file;
      _existingPhotoUrl = null; // user override la photo référence
    });
  }

  void _removePhoto() {
    setState(() {
      _pickedPhoto = null;
      _existingPhotoUrl = null;
    });
  }

  /// Injecte une entrée species_reference (sélectionnée via l'autocomplete)
  /// dans les champs du formulaire. commonName est déjà rempli par
  /// RawAutocomplete via displayStringForOption — on remplit le reste.
  void _applyReferenceSelection(SpeciesReference entry) {
    setState(() {
      _scientificName.text = entry.scientificName;
      if (_description.text.isEmpty) _description.text = entry.description;
      if (_tips.text.isEmpty) _tips.text = entry.tips;
      if (entry.rarityHint != null) {
        _selectedRarity = Rarity.values.firstWhere(
          (r) => r.name == entry.rarityHint,
          orElse: () => _selectedRarity,
        );
      }
      if (entry.photoUrl != null && _pickedPhoto == null) {
        _existingPhotoUrl = entry.photoUrl;
      }
      _refCategoryKey = entry.categoryKey;
      // Reset pour forcer la re-dérivation depuis _refCategoryKey au build.
      _selectedCategoryId = null;
    });
  }

  /// Lookup dans `species_reference` pour pré-remplir description, tips,
  /// rareté suggérée, catégorie et photo. Appelé automatiquement à l'init
  /// si un candidat IA est fourni.
  /// Idempotent : ne ré-écrit pas les champs déjà remplis par l'user.
  Future<void> _lookupReference(String scientificName) async {
    if (_refLoading || scientificName.trim().isEmpty) return;
    setState(() => _refLoading = true);
    try {
      final entry = await ref
          .read(speciesReferenceRepositoryProvider)
          .getByScientificName(scientificName.trim());
      if (!mounted) return;
      if (entry == null) {
        setState(() => _refLoading = false);
        return;
      }
      setState(() {
        _refLoading = false;
        if (_commonName.text.isEmpty) _commonName.text = entry.commonName;
        if (_description.text.isEmpty) _description.text = entry.description;
        if (_tips.text.isEmpty) _tips.text = entry.tips;
        if (entry.rarityHint != null) {
          _selectedRarity = Rarity.values.firstWhere(
            (r) => r.name == entry.rarityHint,
            orElse: () => _selectedRarity,
          );
        }
        if (entry.photoUrl != null && _pickedPhoto == null) {
          _existingPhotoUrl = entry.photoUrl;
        }
        _refCategoryKey = entry.categoryKey;
      });
    } catch (_) {
      // Lookup silencieux — si ça plante (réseau, etc.), on laisse les
      // champs vides et l'user remplit à la main.
      if (mounted) {
        setState(() => _refLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _commonName =
        TextEditingController(text: widget.candidate?.commonName ?? '');
    _scientificName =
        TextEditingController(text: widget.candidate?.scientificName ?? '');
    _description = TextEditingController();
    _tips = TextEditingController();
    _selectedRarity = widget.candidate != null
        ? _rarityFromKey(widget.candidate!.rarityKey)
        : Rarity.common;

    // Si un candidat IA fournit déjà un scientific_name, on cherche dans
    // la banque species_reference pour pré-remplir description/tips/photo
    // sans attendre une action user. Lookup async, n'empêche pas le build.
    final candidateSci = widget.candidate?.scientificName;
    if (candidateSci != null && candidateSci.isNotEmpty) {
      // Déféré au prochain frame pour pas faire un setState pendant initState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lookupReference(candidateSci);
      });
    }
  }

  @override
  void dispose() {
    _commonName.dispose();
    _scientificName.dispose();
    _description.dispose();
    _tips.dispose();
    super.dispose();
  }

  Rarity _rarityFromKey(String key) {
    return Rarity.values.firstWhere(
      (r) => r.name == key,
      orElse: () => Rarity.common,
    );
  }

  Future<void> _submit() async {
    final cn = _commonName.text.trim();
    final sn = _scientificName.text.trim();
    if (cn.isEmpty || sn.isEmpty) {
      setState(() => _error = 'Nom commun et nom scientifique requis.');
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Choisis une catégorie.');
      return;
    }
    if (_selectedZoneIds.isEmpty) {
      setState(() => _error = 'Choisis au moins un territoire.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final desc =
          _description.text.trim().isEmpty ? null : _description.text.trim();
      final tipsText = _tips.text.trim().isEmpty ? null : _tips.text.trim();
      // Upload photo (optionnel) avant la création de l'espèce — comme ça
      // la ligne species naît directement avec son photo_url.
      // Priorité : photo pickée par l'user > URL de la banque référence > null.
      String? photoUrl;
      if (_pickedPhoto != null) {
        final uploaderId = ref.read(currentAuthUserProvider)?.id;
        if (uploaderId != null) {
          photoUrl =
              await ref.read(photoUploadServiceProvider).uploadSpeciesPhoto(
                    file: _pickedPhoto!,
                    uploaderUserId: uploaderId,
                  );
        }
      } else if (_existingPhotoUrl != null) {
        // Réutilise directement l'URL iNat de la banque référence — pas
        // d'upload, on pointe sur le serveur iNat (CC-licensed, stable).
        photoUrl = _existingPhotoUrl;
      }
      // Si l'espèce existe déjà (typiquement : présente dans Oise, on veut
      // la lier à Aisne depuis une obs), on skip le CREATE et on ajoute juste
      // les liens species_zones manquants. Sinon création normale.
      final repo = ref.read(speciesRepositoryProvider);
      final existingSpecies = await repo.getByScientificName(sn);
      final String createdSpeciesId;
      Set<String> zonesToLink;
      if (existingSpecies != null) {
        final alreadyLinked = await repo.getZoneIdsForSpecies(existingSpecies.id);
        zonesToLink = _selectedZoneIds.difference(alreadyLinked);
        createdSpeciesId = existingSpecies.id;
      } else {
        final created = await repo.create(
          commonName: cn,
          scientificName: sn,
          categoryId: _selectedCategoryId!,
          description: desc,
          tips: tipsText,
          photoUrl: photoUrl,
        );
        createdSpeciesId = created.id;
        zonesToLink = _selectedZoneIds;
      }
      if (zonesToLink.isNotEmpty) {
        final inserts = zonesToLink
            .map((zid) => {
                  'species_id': createdSpeciesId,
                  'zone_id': zid,
                  'rarity': _selectedRarity.name,
                })
            .toList();
        await ref
            .read(supabaseClientProvider)
            .from('species_zones')
            .insert(inserts);
      }
      if (mounted) Navigator.of(context).pop(createdSpeciesId);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Erreur BDD : ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_categoriesProvider);
    // Priorité de pré-sélection : candidat IA > banque référence > rien.
    final prefillCategoryKey =
        widget.candidate?.categoryKey ?? _refCategoryKey;
    return Dialog(
      backgroundColor: surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isManual ? 'Nouvelle espèce' : 'Ajouter cette espèce ?',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: forestGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isManual
                    ? "Saisis les infos de cette espèce — elle entrera dans le catalogue de la zone."
                    : "Cette espèce n'est pas encore dans le catalogue de la zone.",
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_isManual) ...[
                _DialogLabel('Espèce'),
                const SizedBox(height: 4),
                SpeciesReferenceAutocomplete(
                  controller: _commonName,
                  onSelected: _applyReferenceSelection,
                ),
                const SizedBox(height: 8),
                Text(
                  "Tape le nom commun, sélectionne dans la liste : "
                  "tous les champs se remplissent. Si l'espèce n'est pas "
                  "dans la banque, remplis manuellement ci-dessous.",
                  style: GoogleFonts.karla(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _DialogLabel('Nom scientifique'),
                const SizedBox(height: 4),
                _DialogTextInput(
                  controller: _scientificName,
                  hint: 'Ex. Buteo buteo',
                  italic: true,
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8E0CE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _commonName.text,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: forestGreen,
                        ),
                      ),
                      Text(
                        _scientificName.text,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: terracotta,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              _DialogLabel('Catégorie'),
              const SizedBox(height: 6),
              categoriesAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Erreur : $e',
                  style: GoogleFonts.karla(color: textMuted),
                ),
                data: (categories) {
                  // Pré-sélectionne la catégorie suggérée par l'IA ou par
                  // la banque species_reference (cf. _refCategoryKey).
                  if (prefillCategoryKey != null) {
                    _selectedCategoryId ??= categories
                        .cast<model.Category?>()
                        .firstWhere(
                          (cat) => cat!.icon == prefillCategoryKey,
                          orElse: () => null,
                        )
                        ?.id;
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: const Color(0xFFE8E0CE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCategoryId = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              _DialogLabel('Rareté locale'),
              const SizedBox(height: 6),
              DropdownButtonFormField<Rarity>(
                initialValue: _selectedRarity,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: const Color(0xFFE8E0CE),
                      width: 1.5,
                    ),
                  ),
                ),
                items: Rarity.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(_rarityLabel(r)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    v != null ? setState(() => _selectedRarity = v) : null,
              ),
              const SizedBox(height: 12),
              _DialogLabel('Territoires'),
              const SizedBox(height: 6),
              MultiZoneSelector(
                selectedIds: _selectedZoneIds,
                onChanged: (next) => setState(() {
                  _selectedZoneIds
                    ..clear()
                    ..addAll(next);
                }),
              ),
              const SizedBox(height: 4),
              Text(
                "La rareté ci-dessus s'applique à tous les territoires "
                "cochés. Tu pourras l'ajuster par territoire plus tard via "
                "l'édition de l'espèce.",
                style: GoogleFonts.karla(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _DialogLabel('Description (optionnelle)'),
              const SizedBox(height: 4),
              _DialogTextInput(
                controller: _description,
                hint: 'Habitat, comportement, signes distinctifs…',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _DialogLabel('Pour la débusquer (optionnel)'),
              const SizedBox(height: 4),
              _DialogTextInput(
                controller: _tips,
                hint: 'Où, quand, comment chercher cette espèce…',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _DialogLabel("Photo d'illustration (optionnelle)"),
              const SizedBox(height: 6),
              SpeciesPhotoPicker(
                pickedFile: _pickedPhoto,
                existingUrl: _existingPhotoUrl,
                onPick: _pickPhoto,
                onRemove: _removePhoto,
                height: 120,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.karla(
                    color: const Color(0xFFFF5A5A),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.karla(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: forestGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: surfaceBase,
                              ),
                            )
                          : Text(
                              'AJOUTER',
                              style: GoogleFonts.karla(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _rarityLabel(Rarity r) => switch (r) {
        Rarity.common => 'Commun',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Épique',
        Rarity.legendary => 'Légendaire',
      };
}

final _categoriesProvider = FutureProvider<List<model.Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getAll();
});


/// Petit label majuscule espacé pour les sections du dialog d'ajout d'espèce.
class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.karla(
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
        color: textSecondary,
      ),
    );
  }
}

/// TextField stylisé cohérent avec les Dropdown du dialog (même bordure et
/// fond crème). [maxLines] permet d'agrandir pour description/tips.
class _DialogTextInput extends StatelessWidget {
  const _DialogTextInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.italic = false,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: italic
          ? GoogleFonts.cormorantGaramond(
              fontStyle: FontStyle.italic,
              fontSize: 16,
              color: textPrimary,
            )
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.karla(fontSize: 13, color: textMuted),
        filled: true,
        fillColor: surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8E0CE), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE8E0CE), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: forestGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

/// Barre d'outils au-dessus de la mini-carte : recherche de lieu (forward
/// geocoding Mapbox) + bouton "revenir à la position de la photo".
///
/// Le bouton retour photo est TOUJOURS visible dès que la photo a un EXIF GPS
/// (choix uniformité UX : règle simple > branche conditionnelle sur distance).
/// Si on est déjà pile sur la position, le tap est un no-op inoffensif.
class _LocationTools extends ConsumerStatefulWidget {
  const _LocationTools({
    required this.photo,
    required this.onLocationPicked,
  });

  final PickedPhoto? photo;
  final ValueChanged<({double lat, double lng})> onLocationPicked;

  @override
  ConsumerState<_LocationTools> createState() => _LocationToolsState();
}

class _LocationToolsState extends ConsumerState<_LocationTools> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounce 350 ms avant de taper l'API Mapbox — un forward-geocode par
  /// frappe coûterait cher et ferait clignoter la liste.
  Future<List<PlaceSuggestion>> _searchDebounced(String query) async {
    _debounce?.cancel();
    final completer = Completer<List<PlaceSuggestion>>();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ref
            .read(geocodingServiceProvider)
            .forwardGeocode(query);
        if (!completer.isCompleted) completer.complete(results);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(const []);
      }
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final photoHasGps = widget.photo?.hasGps ?? false;

    return Row(
      children: [
        Expanded(
          child: RawAutocomplete<PlaceSuggestion>(
            textEditingController: _controller,
            focusNode: _focusNode,
            displayStringForOption: (o) => o.name,
            optionsBuilder: (value) => _searchDebounced(value.text),
            fieldViewBuilder: (context, controller, focusNode, _) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: GoogleFonts.karla(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Rechercher une ville ou un lieu…',
                  hintStyle: GoogleFonts.karla(fontSize: 13, color: textMuted),
                  prefixIcon:
                      const Icon(Icons.search, size: 18, color: forestGreen),
                  filled: true,
                  fillColor: surfaceCard,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8E0CE), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8E0CE), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: forestGreen, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              );
            },
            optionsViewBuilder: (context, onSelectedCallback, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: surfaceBase,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 6,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 240, maxWidth: 420),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final o = options.elementAt(i);
                        return InkWell(
                          onTap: () => onSelectedCallback(o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFE8E0CE),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.name,
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: forestGreen,
                                  ),
                                ),
                                if (o.description.isNotEmpty)
                                  Text(
                                    o.description,
                                    style: GoogleFonts.karla(
                                      fontSize: 11,
                                      color: textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onSelected: (o) {
              // Vide le champ après sélection — sinon le nom reste et
              // relance l'autocomplete au prochain focus.
              _controller.clear();
              _focusNode.unfocus();
              widget.onLocationPicked((lat: o.lat, lng: o.lng));
            },
          ),
        ),
        if (photoHasGps) ...[
          const SizedBox(width: 8),
          // Pill "📷 Photo" — le label rend l'action explicite (l'icône seule
          // n'était pas devinable, cf. feedback UX).
          Material(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => widget.onLocationPicked((
                lat: widget.photo!.latitude!,
                lng: widget.photo!.longitude!,
              )),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE8E0CE),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: forestGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Photo',
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: forestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Mini-carte Mapbox dans le form. Le marker terracotta est fixé visuellement
/// au centre de la carte (overlay Flutter, pas un marker Mapbox). Au drag, la
/// carte bouge sous le marker — quand elle s'immobilise, on lit la nouvelle
/// position du centre via [getCameraState].
class _MiniMapPicker extends StatefulWidget {
  const _MiniMapPicker({
    required this.lat,
    required this.lng,
    required this.onPositionChanged,
  });

  final double lat;
  final double lng;
  final ValueChanged<({double lat, double lng})> onPositionChanged;

  @override
  State<_MiniMapPicker> createState() => _MiniMapPickerState();
}

class _MiniMapPickerState extends State<_MiniMapPicker> {
  MapboxMap? _map;

  // Viewport mémoïsé au mount. Indispensable : à chaque rebuild parent,
  // créer une nouvelle instance CameraViewportState() ferait que Mapbox
  // ré-applique le viewport (par comparaison d'identité), ce qui reset le
  // zoom à 11 à chaque pan/zoom de l'utilisateur. En gardant la même
  // instance, Mapbox ignore.
  late final CameraViewportState _initialViewport;

  // Dernière position reportée au parent via onPositionChanged. Sert à
  // distinguer un changement externe (photo avec GPS, retour fullscreen,
  // bouton ma-position) — pour lequel on doit flyTo — d'un écho de notre
  // propre pan (parent setState → rebuild) — pour lequel un flyTo
  // réinitialiserait le zoom.
  double? _lastReportedLat;
  double? _lastReportedLng;

  /// True dès que l'user a pan/scroll la carte. Avant ça, le 1er MapIdle
  /// rapporterait la position par défaut (Compiègne quand le parent n'a pas
  /// fourni de lat/lng) au parent, qui croirait que c'est un choix manuel
  /// → fausse zone détectée. On ne rapporte donc qu'après interaction.
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    _initialViewport = CameraViewportState(
      center: Point(coordinates: Position(widget.lng, widget.lat)),
      zoom: 11,
    );
  }

  @override
  void didUpdateWidget(_MiniMapPicker old) {
    super.didUpdateWidget(old);
    final changed = (widget.lat - old.lat).abs() > 1e-9 ||
        (widget.lng - old.lng).abs() > 1e-9;
    if (!changed) return;
    final lr = _lastReportedLat;
    final lrLng = _lastReportedLng;
    final isEcho = lr != null &&
        lrLng != null &&
        (widget.lat - lr).abs() < 1e-9 &&
        (widget.lng - lrLng).abs() < 1e-9;
    if (!isEcho) {
      _flyTo(lat: widget.lat, lng: widget.lng);
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  }

  Future<void> _flyTo({required double lat, required double lng}) async {
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 13,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _onMapIdle(MapIdleEventData _) async {
    // 1er MapIdle après chargement de la carte : si l'user n'a rien fait,
    // c'est juste Mapbox qui s'est posé sur la position par défaut. On ne
    // reporte pas — sinon le parent considère que (Compiègne) est un choix
    // de l'user et résout la zone "Oise" alors qu'aucune position réelle
    // n'a été fournie.
    if (!_userInteracted) return;
    final map = _map;
    if (map == null) return;
    final state = await map.getCameraState();
    final pos = state.center.coordinates;
    final lat = pos.lat.toDouble();
    final lng = pos.lng.toDouble();
    _lastReportedLat = lat;
    _lastReportedLng = lng;
    widget.onPositionChanged((lat: lat, lng: lng));
  }

  Future<void> _openFullscreen() async {
    final result = await Navigator.of(context).push<({double lat, double lng})>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenMapPicker(
          initialLat: widget.lat,
          initialLng: widget.lng,
        ),
      ),
    );
    if (result != null) {
      widget.onPositionChanged(result);
      await _flyTo(lat: result.lat, lng: result.lng);
    }
  }

  Future<void> _centerOnUser() async {
    final result =
        await ProviderScope.containerOf(context, listen: false)
            .read(locationServiceProvider)
            .getCurrentPosition();
    if (!mounted) return;
    switch (result) {
      case LocationSuccess(:final lat, :final lng):
        widget.onPositionChanged((lat: lat, lng: lng));
        await _flyTo(lat: lat, lng: lng);
      case LocationServiceDisabled():
        _snackbar('Active la localisation dans tes réglages système.');
      case LocationDenied():
        _snackbar('Permission refusée.');
      case LocationDeniedForever():
        _snackbar(
          'Permission refusée. Active-la dans Réglages → Apps → Spotted.',
        );
      case LocationError(:final message):
        _snackbar('Erreur de localisation : $message');
    }
  }

  void _snackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            MapWidget(
              viewport: _initialViewport,
              styleUri: MapboxStyles.OUTDOORS,
              onMapCreated: _onMapCreated,
              onMapIdleListener: _onMapIdle,
              // Tout scroll/pan = interaction utilisateur. Active la reporting
              // côté _onMapIdle (qui était sinon mute pour éviter le bug
              // "défaut Compiègne reporté au mount").
              onScrollListener: (_) => _userInteracted = true,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              },
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Icon(
                  Icons.location_on,
                  color: terracotta,
                  size: 36,
                ),
              ),
            ),
            // Bouton fullscreen, top-right
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: surfaceBase.withValues(alpha: 0.95),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openFullscreen,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.fullscreen,
                      color: forestGreen,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            // Bouton "ma position", bottom-right
            Positioned(
              bottom: 6,
              right: 6,
              child: Material(
                color: surfaceBase.withValues(alpha: 0.95),
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _centerOnUser,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.my_location,
                      color: forestGreen,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 6,
              right: 50,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceBase.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Glisse la carte pour ajuster',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page plein écran pour ajuster la position avec une grande carte.
/// Renvoie en pop la position du centre quand l'utilisateur valide.
class _FullscreenMapPicker extends StatefulWidget {
  const _FullscreenMapPicker({
    required this.initialLat,
    required this.initialLng,
  });

  final double initialLat;
  final double initialLng;

  @override
  State<_FullscreenMapPicker> createState() => _FullscreenMapPickerState();
}

class _FullscreenMapPickerState extends State<_FullscreenMapPicker> {
  MapboxMap? _map;
  double _lat = 0;
  double _lng = 0;

  // Idem que mini-map : on mémoize le viewport pour qu'il ne soit pas
  // re-appliqué à chaque setState (sinon le zoom user reset à chaque pan).
  late final CameraViewportState _initialViewport;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
    _initialViewport = CameraViewportState(
      center: Point(coordinates: Position(widget.initialLng, widget.initialLat)),
      zoom: 12,
    );
  }

  Future<void> _onMapIdle(MapIdleEventData _) async {
    final map = _map;
    if (map == null) return;
    final state = await map.getCameraState();
    final pos = state.center.coordinates;
    if (mounted) {
      setState(() {
        _lat = pos.lat.toDouble();
        _lng = pos.lng.toDouble();
      });
    }
  }

  /// Récupère la position courante de la map directement (pas via le state),
  /// pour éviter le cas où onMapIdleListener n'a pas encore tiré.
  Future<void> _confirm() async {
    final map = _map;
    if (map == null) {
      Navigator.of(context).pop();
      return;
    }
    final state = await map.getCameraState();
    final pos = state.center.coordinates;
    if (!mounted) return;
    Navigator.of(context).pop(
      (lat: pos.lat.toDouble(), lng: pos.lng.toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ajuster la position',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: forestGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          MapWidget(
            viewport: _initialViewport,
            styleUri: MapboxStyles.OUTDOORS,
            onMapCreated: (m) async {
              _map = m;
              await m.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
            },
            onMapIdleListener: _onMapIdle,
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_on,
                color: terracotta,
                size: 44,
              ),
            ),
          ),
          // Coordonnées live en haut
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: surfaceBase.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: forestGreen,
                ),
              ),
            ),
          ),
          // Bouton valider en bas
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: FilledButton.icon(
              onPressed: _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: forestGreen,
                foregroundColor: surfaceBase,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check),
              label: Text(
                'VALIDER CETTE POSITION',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordsField extends StatelessWidget {
  const _CoordsField({this.lat, this.lng});

  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context) {
    final text = (lat == null || lng == null)
        ? "Pas de position — ajoute une photo géolocalisée ou place le point"
        : '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}';
    return _ReadOnlyField(text: text, icon: Icons.location_on_outlined);
  }
}

class _SpeciesField extends StatelessWidget {
  const _SpeciesField({
    required this.speciesAsync,
    required this.locked,
    required this.onTap,
  });

  final AsyncValue<Species?> speciesAsync;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return speciesAsync.when(
      loading: () => const _ReadOnlyField(
        text: 'Chargement…',
        icon: Icons.pets,
      ),
      error: (e, _) => const _ReadOnlyField(
        text: 'Erreur de chargement',
        icon: Icons.error_outline,
      ),
      data: (s) => _ReadOnlyField(
        text: s?.commonName ?? 'Choisir une espèce',
        icon: locked ? Icons.lock_outline : Icons.pets,
        onTap: onTap,
      ),
    );
  }
}


class _SpeciesPickerSheet extends ConsumerStatefulWidget {
  const _SpeciesPickerSheet({required this.zoneId});

  final String zoneId;

  @override
  ConsumerState<_SpeciesPickerSheet> createState() =>
      _SpeciesPickerSheetState();
}

class _SpeciesPickerSheetState extends ConsumerState<_SpeciesPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allSpeciesAsync = ref.watch(_zoneSpeciesProvider(widget.zoneId));
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E0CE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Rechercher une espèce…',
                  prefixIcon: const Icon(Icons.search, color: textSecondary),
                  filled: true,
                  fillColor: surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bouton pour ajouter une espèce vraiment nouvelle (jamais
              // observée nulle part). Ouvre _AddSpeciesDialog en mode manuel
              // (sans candidat IA, tous les champs éditables) et pop le
              // picker avec l'id de l'espèce créée. Pré-coche la zone du
              // picker (= zone détectée pour l'obs en cours).
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final newId = await showDialog<String>(
                      context: context,
                      builder: (_) =>
                          _AddSpeciesDialog(initialZoneId: widget.zoneId),
                    );
                    if (newId != null && mounted) {
                      ref.invalidate(_zoneSpeciesProvider);
                      ref.invalidate(speciesByCategoryInZoneProvider);
                      ref.invalidate(categoriesWithProgressProvider);
                      if (context.mounted) {
                        Navigator.of(context).pop(newId);
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: forestGreen,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline,
                            size: 18, color: forestGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ajouter une nouvelle espèce',
                                style: GoogleFonts.karla(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: forestGreen,
                                ),
                              ),
                              Text(
                                "Pas dans la liste ? Crée-la (nom, catégorie, rareté…).",
                                style: GoogleFonts.karla(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: allSpeciesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Erreur : $e',
                    style: GoogleFonts.karla(color: textMuted),
                  ),
                  data: (items) {
                    final filtered = items.where((it) {
                      if (_query.isEmpty) return true;
                      return it.species.commonName
                              .toLowerCase()
                              .contains(_query) ||
                          it.species.scientificName
                              .toLowerCase()
                              .contains(_query);
                    }).toList();
                    return ListView.separated(
                      controller: controller,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final it = filtered[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                              color: Color(0xFFE8E0CE),
                            ),
                          ),
                          title: Text(
                            it.species.commonName,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: forestGreen,
                            ),
                          ),
                          subtitle: Text(
                            it.species.scientificName,
                            style: GoogleFonts.karla(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: terracotta,
                            ),
                          ),
                          trailing: Text(
                            _rarityLabel(it.rarity),
                            style: GoogleFonts.karla(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                              color: _rarityColor(it.rarity),
                            ),
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(it.species.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _rarityLabel(Rarity r) => switch (r) {
        Rarity.common => 'COMMUN',
        Rarity.rare => 'RARE',
        Rarity.epic => 'ÉPIQUE',
        Rarity.legendary => 'LÉGENDAIRE',
      };

  static Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => rarityCommon,
        Rarity.rare => rarityRare,
        Rarity.epic => rarityEpic,
        Rarity.legendary => rarityLegendary,
      };
}

/// Dialog de récompense après une observation enregistrée.
/// Intensité graduée selon (rarity, isFirst) — palette + sparkles + halo
/// adaptés à chaque rareté, sans jamais sortir le confetti (trop bruyant).
///
///   - commun (re-obs)        : scale-in léger, halo absent, haptic doux
///   - commun (1ʳᵉ obs)        : + pastille rareté + halo discret
///   - rare 1ʳᵉ obs            : + halo bleu modéré pulsant
///   - épique 1ʳᵉ obs          : + halo violet pulsant + 3 sparkles ✨ orbitant
///   - légendaire 1ʳᵉ obs      : + halo doré intense + 6 sparkles ✨ + shimmer
///                              sur la pastille LÉGENDAIRE + haptic lourd ×3
class _DiscoveryDialog extends StatefulWidget {
  const _DiscoveryDialog({
    required this.rarity,
    required this.points,
    required this.isFirst,
  });

  final Rarity rarity;
  final int points;
  final bool isFirst;

  @override
  State<_DiscoveryDialog> createState() => _DiscoveryDialogState();
}

class _DiscoveryDialogState extends State<_DiscoveryDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _scale;
  late final Animation<double> _pointsTween;
  late final AnimationController _halo;

  bool get _isLegendary => widget.rarity == Rarity.legendary;
  bool get _isEpic => widget.rarity == Rarity.epic;
  bool get _showHalo => widget.isFirst && widget.rarity != Rarity.common;

  /// Nombre de sparkles autour de l'icône (0 / 3 / 6 selon la rareté).
  /// Limité aux 1ʳᵉs obs (re-obs reste sobre).
  int get _sparkleCount {
    if (!widget.isFirst) return 0;
    if (_isLegendary) return 6;
    if (_isEpic) return 3;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    // Entrée : scale + bounce. Durée plus longue pour le légendaire pour
    // donner le temps au compteur de points d'aller plus loin.
    _entry = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _isLegendary ? 1400 : 1000),
    );
    _scale = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.5, curve: Curves.elasticOut),
    );
    _pointsTween = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
    );
    // Halo : pulse continu. Uniquement pour rare/épique/légendaire.
    _halo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Démarre l'animation après le 1er frame pour que la haptic soit synchro
    // avec le scale-in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entry.forward();
      _triggerHaptics();
    });
  }

  Future<void> _triggerHaptics() async {
    // Vibration adaptée à la rareté. Re-obs commun = juste un selectionClick.
    if (!widget.isFirst || widget.rarity == Rarity.common) {
      await HapticFeedback.selectionClick();
      return;
    }
    if (_isLegendary) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    } else if (_isEpic) {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _halo.dispose();
    super.dispose();
  }

  Color get _rarityColor => switch (widget.rarity) {
        Rarity.common => rarityCommon,
        Rarity.rare => rarityRare,
        Rarity.epic => rarityEpic,
        Rarity.legendary => rarityLegendary,
      };

  String get _rarityLabel => switch (widget.rarity) {
        Rarity.common => 'COMMUN',
        Rarity.rare => 'RARE',
        Rarity.epic => 'ÉPIQUE',
        Rarity.legendary => 'LÉGENDAIRE',
      };

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor;
    // Pastille de rareté avec shimmer pour le légendaire (effet "or vivant").
    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        _rarityLabel,
        style: GoogleFonts.karla(
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
    if (_isLegendary) {
      pill = pill.animate(onPlay: (c) => c.repeat()).shimmer(
            duration: const Duration(milliseconds: 1800),
            color: goldLight.withValues(alpha: 0.7),
          );
    }
    return Dialog(
      backgroundColor: surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedBuilder(
        animation: _entry,
        builder: (_, _) {
          // Scale-in léger pour la card entière (subtil, pas de bounce ici).
          final cardScale = 0.92 + 0.08 * _scale.value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: cardScale,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pastille rareté (premier obs seulement)
                  if (widget.isFirst) ...[
                    pill,
                    const SizedBox(height: 12),
                  ],
                  // Icône + halo + sparkles orbitants
                  _HeroIcon(
                    color: color,
                    scale: _scale,
                    halo: _halo,
                    showHalo: _showHalo,
                    showSparkle: widget.isFirst,
                    sparkleCount: _sparkleCount,
                  ),
                      const SizedBox(height: 14),
                      Text(
                        widget.isFirst ? 'Découverte !' : 'Marqueur ajouté',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: forestGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Compteur de points qui s'incrémente de 0 → points
                      AnimatedBuilder(
                        animation: _pointsTween,
                        builder: (_, _) {
                          final current =
                              (_pointsTween.value * widget.points).round();
                          return Text(
                            '+ $current points',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: gold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: forestGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'CONTINUER',
                          style: GoogleFonts.karla(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
  }
}

/// Cercle gradient + icône ✨, avec halo pulsant en option pour les raretés
/// hautes. Sparkles orbitants quand sparkleCount > 0 (épique/légendaire).
class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
    required this.color,
    required this.scale,
    required this.halo,
    required this.showHalo,
    required this.showSparkle,
    required this.sparkleCount,
  });

  final Color color;
  final Animation<double> scale;
  final Animation<double> halo;
  final bool showHalo;
  final bool showSparkle;

  /// Nombre de sparkles ✨ disposés en cercle autour de l'icône.
  /// 0 = pas d'effet ; 3 = épique ; 6 = légendaire.
  final int sparkleCount;

  /// Diamètre du cercle imaginaire sur lequel les sparkles sont positionnés.
  /// Légèrement plus grand que l'icône (88px) pour qu'ils flottent autour.
  static const double _orbitRadius = 60;

  @override
  Widget build(BuildContext context) {
    final size = sparkleCount > 0 ? _orbitRadius * 2 + 24 : 88.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Sparkles orbitants : un par position calculée, chacun avec un
          // délai différent pour un effet "scintillement asynchrone" plus
          // organique qu'un blink synchronisé.
          for (var i = 0; i < sparkleCount; i++) _buildSparkle(i),
          // Icône centrale (toujours présente)
          AnimatedBuilder(
            animation: Listenable.merge([scale, halo]),
            builder: (_, _) {
              final s = scale.value;
              final haloAlpha = showHalo ? 0.35 + 0.35 * halo.value : 0.0;
              final haloBlur = showHalo ? 18 + halo.value * 14 : 0.0;
              return Transform.scale(
                scale: 0.4 + 0.6 * s.clamp(0.0, 1.0),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.75)],
                    ),
                    boxShadow: showHalo
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: haloAlpha),
                              blurRadius: haloBlur,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    showSparkle ? Icons.auto_awesome : Icons.check,
                    size: 44,
                    color: surfaceBase,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSparkle(int index) {
    final angle = (index / sparkleCount) * 2 * math.pi - math.pi / 2;
    final dx = _orbitRadius * math.cos(angle);
    final dy = _orbitRadius * math.sin(angle);
    // Délai stagger : chaque sparkle commence son cycle à un moment différent
    // pour un effet "constellation vivante" vs blink synchronisé.
    final delay = Duration(milliseconds: 120 * index);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: const Text('✨', style: TextStyle(fontSize: 16))
          .animate(onPlay: (c) => c.repeat())
          .scale(
            delay: delay,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
          )
          .then(delay: const Duration(milliseconds: 700))
          .scale(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeIn,
            begin: const Offset(1, 1),
            end: const Offset(0, 0),
          )
          .then(delay: const Duration(milliseconds: 400)),
    );
  }
}

// =============================================================
// Banner de statut territorial (photo-first)
// =============================================================
//
// Remplace l'ancien _NoGpsTipBanner + _PlaceDisplay : un seul widget qui
// matérialise l'état de la résolution. Évite à l'user de "deviner" si la
// position est valide — au lieu d'attendre une erreur au submit.

class _ZoneStatusBanner extends StatelessWidget {
  const _ZoneStatusBanner({
    required this.resolution,
    required this.hasPhoto,
    required this.photoHasGps,
  });

  final _ZoneResolution? resolution;
  final bool hasPhoto;
  final bool photoHasGps;

  @override
  Widget build(BuildContext context) {
    final res = resolution;
    // Aucune position connue → hint "place le point sur la carte".
    if (res == null) {
      final msg = !hasPhoto
          ? 'Importe une photo géolocalisée ou place le point sur la carte ci-dessous.'
          : 'Photo sans GPS — place le point sur la carte ci-dessous.';
      return _BannerShell(
        color: textMuted,
        icon: Icons.place_outlined,
        title: 'Position requise',
        body: msg,
      );
    }
    if (res is _ZoneResolving) {
      return _BannerShell(
        color: textSecondary,
        icon: Icons.hourglass_top_outlined,
        title: 'Résolution du lieu…',
        body: null,
      );
    }
    if (res is _ZoneError) {
      return _BannerShell(
        color: terracotta,
        icon: Icons.warning_amber_outlined,
        title: 'Hors zone curée',
        body: res.message,
      );
    }
    final resolved = res as _ZoneResolved;
    return _BannerShell(
      color: forestGreen,
      icon: Icons.check_circle_outline,
      title: resolved.placeLabel ?? resolved.zone.name,
      body: photoHasGps
          ? 'Position lue dans la photo · ${resolved.zone.name}'
          : 'Position confirmée · ${resolved.zone.name}',
    );
  }
}

class _BannerShell extends StatelessWidget {
  const _BannerShell({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body!,
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      color: textPrimary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Sélecteur de rareté inline (photo-first)
// =============================================================
//
// Affiché quand l'espèce sélectionnée n'a pas de ligne species_zones pour la
// zone détectée. Remplace l'ancien _PickRarityForZoneDialog qui surgissait au
// submit. À l'enregistrement de l'obs, on insère la ligne manquante avec la
// valeur choisie.

class _RarityPickerInline extends StatelessWidget {
  const _RarityPickerInline({
    required this.zoneName,
    required this.selected,
    required this.onSelected,
  });

  final String zoneName;
  final Rarity? selected;
  final ValueChanged<Rarity> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 16, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cette espèce n\'est pas encore curée en $zoneName.',
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choisis sa rareté locale — on l\'ajoutera au catalogue de la zone.',
            style: GoogleFonts.karla(
              fontSize: 11,
              color: textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in Rarity.values)
                _RarityPickerChip(
                  rarity: r,
                  selected: selected == r,
                  onTap: () => onSelected(r),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RarityPickerChip extends StatelessWidget {
  const _RarityPickerChip({
    required this.rarity,
    required this.selected,
    required this.onTap,
  });

  final Rarity rarity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (rarity) {
      Rarity.common => rarityCommon,
      Rarity.rare => rarityRare,
      Rarity.epic => rarityEpic,
      Rarity.legendary => rarityLegendary,
    };
    final label = switch (rarity) {
      Rarity.common => 'Commun',
      Rarity.rare => 'Rare',
      Rarity.epic => 'Épique',
      Rarity.legendary => 'Légendaire',
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected ? surfaceBase : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.karla(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? surfaceBase : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// Résolution territoriale (photo-first) — sealed types
// =============================================================
//
// Représente l'état de la résolution de zone depuis la paire (lat, lng) :
//   - resolving : appel reverse-geocode + lookup zone en cours
//   - resolved  : zone curée trouvée (+ libellé "Forêt de Compiègne, Oise")
//   - error     : hors France / hors zone curée / geocoding raté

sealed class _ZoneResolution {
  const _ZoneResolution();
}

class _ZoneResolving extends _ZoneResolution {
  const _ZoneResolving();
}

class _ZoneResolved extends _ZoneResolution {
  const _ZoneResolved({required this.zone, this.placeLabel});

  final Zone zone;
  final String? placeLabel;
}

class _ZoneError extends _ZoneResolution {
  const _ZoneError(this.message);

  final String message;
}

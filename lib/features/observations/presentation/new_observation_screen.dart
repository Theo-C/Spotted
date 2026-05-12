import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedSpeciesId = widget.preselectedSpeciesId;
  }

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
    });
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

  Future<void> _acceptCandidate(SpeciesCandidate candidate) async {
    if (candidate.scientificName.isEmpty) return;
    final oise = await ref.read(oiseZoneProvider.future);
    final allSpecies = await ref.read(_zoneSpeciesProvider(oise.id).future);
    final scientificLower = candidate.scientificName.toLowerCase();
    final match = allSpecies.cast<({Species species, Rarity rarity})?>().firstWhere(
          (s) =>
              s!.species.scientificName.toLowerCase() == scientificLower,
          orElse: () => null,
        );
    if (!mounted) return;

    if (match != null) {
      setState(() => _selectedSpeciesId = match.species.id);
    } else {
      // Espèce non curée → dialog d'ajout in-place.
      final newId = await showDialog<String>(
        context: context,
        builder: (_) =>
            _AddSpeciesDialog(candidate: candidate, zoneId: oise.id),
      );
      if (newId != null && mounted) {
        ref.invalidate(_zoneSpeciesProvider);
        ref.invalidate(speciesByCategoryInZoneProvider);
        ref.invalidate(categoriesWithProgressProvider);
        setState(() => _selectedSpeciesId = newId);
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
    final oise = await ref.read(oiseZoneProvider.future);
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SpeciesPickerSheet(zoneId: oise.id),
    );
    if (result != null) setState(() => _selectedSpeciesId = result);
  }

  Future<void> _submit() async {
    if (_selectedSpeciesId == null) {
      setState(() => _error = 'Choisis une espèce.');
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
      final lat = _lat ?? 49.41; // centre approximatif Oise (fallback EXIF absent)
      final lng = _lng ?? 2.82;

      // Détection territoire dynamique : on lookup la zone curée correspondant
      // au département détecté par geocoding. Bloque si hors France ou région
      // pas curée. Photo sans GPS → fallback Oise (centre par défaut).
      Zone detectedZone;
      if (_lat != null && _lng != null) {
        final geocoding = await ref
            .read(geocodingServiceProvider)
            .reverseGeocode(lat: _lat!, lng: _lng!);
        final country = geocoding?.country;
        final region = geocoding?.region;

        // 1. Geocoding totalement raté → on bloque (sécurité).
        if (geocoding == null ||
            (country == null && region == null && geocoding.place == null)) {
          if (mounted) {
            setState(() {
              _submitting = false;
              _error =
                  'Impossible de déterminer le lieu. Vérifie ta connexion et réessaie, ou repositionne le marqueur sur la mini-carte.';
            });
          }
          return;
        }

        // 2. Hors France → bloque.
        if (country != null && country != 'France') {
          if (mounted) {
            setState(() {
              _submitting = false;
              _error =
                  'Cette position est en « $country ». Seules les zones France curées sont supportées.';
            });
          }
          return;
        }

        // 3. Lookup zone curée par nom de région.
        final zones = await ref.read(zoneRepositoryProvider).getAll();
        final matched = zones.cast<Zone?>().firstWhere(
              (z) => z!.name == region,
              orElse: () => null,
            );
        if (matched == null) {
          if (mounted) {
            setState(() {
              _submitting = false;
              _error =
                  'Cette position est en « ${region ?? 'région inconnue'} ». '
                  'Zones curées pour l\'instant : ${zones.map((z) => z.name).join(', ')}. '
                  'Repositionne le marqueur ou choisis une autre photo.';
            });
          }
          return;
        }
        detectedZone = matched;
      } else {
        // Fallback : pas de GPS, défaut Oise.
        detectedZone = await ref.read(zoneByShortCodeProvider('60').future);
      }

      // Rareté locale (de la zone détectée — peut différer entre Oise/Aisne)
      final rarityRow = await client
          .from('species_zones')
          .select('rarity')
          .eq('species_id', speciesId)
          .eq('zone_id', detectedZone.id)
          .maybeSingle();
      final Rarity rarity;
      if (rarityRow != null) {
        rarity = Rarity.values
            .firstWhere((r) => r.name == (rarityRow['rarity'] as String));
      } else {
        // Espèce pas encore curée sur cette zone (ex: Merle noir observé en
        // Aisne mais seulement listé en Oise). On demande à l'utilisateur de
        // confirmer la rareté locale, pré-remplie avec celle d'une autre zone
        // curée si dispo (proba équivalente), sinon `common`. À la confirmation,
        // on crée le lien species_zones pour que les futures obs ne repassent
        // pas par ce dialog et que l'espèce apparaisse dans la liste de la zone.
        final anyZoneRow = await client
            .from('species_zones')
            .select('rarity')
            .eq('species_id', speciesId)
            .limit(1)
            .maybeSingle();
        final defaultRarity = anyZoneRow != null
            ? Rarity.values.firstWhere(
                (r) => r.name == (anyZoneRow['rarity'] as String),
              )
            : Rarity.common;
        final speciesForDialog =
            await ref.read(speciesRepositoryProvider).getById(speciesId);
        if (!mounted) return;
        final picked = await showDialog<Rarity>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _PickRarityForZoneDialog(
            speciesCommonName: speciesForDialog.commonName,
            zoneName: detectedZone.name,
            initialRarity: defaultRarity,
          ),
        );
        if (!mounted) return;
        if (picked == null) {
          // User a annulé → on stoppe la création d'obs.
          setState(() {
            _submitting = false;
            _error = null;
          });
          return;
        }
        rarity = picked;
        await client.from('species_zones').insert({
          'species_id': speciesId,
          'zone_id': detectedZone.id,
          'rarity': rarity.name,
        });
        // Le catalogue de la zone vient de changer → invalide les caches qui
        // listent les espèces curées.
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
      final pointsEarned = observationPoints(
        rarity: rarity,
        isFirst: isFirst,
        hasPhoto: photoUrl != null,
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
            if (_photo != null && !_photo!.hasGps) ...[
              const SizedBox(height: 12),
              const _NoGpsTipBanner(),
            ],
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
            _MiniMapPicker(
              lat: _lat ?? 49.41,
              lng: _lng ?? 2.82,
              onPositionChanged: (pos) {
                setState(() {
                  _lat = pos.lat;
                  _lng = pos.lng;
                });
              },
            ),
            const SizedBox(height: 6),
            _CoordsField(lat: _lat, lng: _lng),
            if (_lat != null && _lng != null) ...[
              const SizedBox(height: 6),
              _PlaceDisplay(lat: _lat!, lng: _lng!),
            ],
            const SizedBox(height: 16),
            const _Label('Espèce'),
            const SizedBox(height: 6),
            _SpeciesField(
              speciesAsync: speciesAsync,
              locked: widget.preselectedSpeciesId != null,
              onTap: widget.preselectedSpeciesId != null ? null : _pickSpecies,
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

class _NoGpsTipBanner extends StatelessWidget {
  const _NoGpsTipBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: terracotta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: terracotta.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: terracotta),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.karla(
                  fontSize: 12,
                  color: textPrimary,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: "Pas de GPS dans cette photo. ",
                    style: GoogleFonts.karla(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        "Active « Enregistrer la localisation » dans ton app caméra "
                        "pour automatiser les futures obs. En attendant, ajuste la position "
                        "manuellement sur la mini-carte ci-dessous.",
                  ),
                ],
              ),
            ),
          ),
        ],
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
    required this.onAcceptCandidate,
    required this.onDismiss,
  });

  final bool identifying;
  final SpeciesIdentification? identification;
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
          for (var i = 0; i < id.candidates.length; i++) ...[
            _CandidateRow(
              candidate: id.candidates[i],
              rank: i + 1,
              onTap: () => onAcceptCandidate(id.candidates[i]),
            ),
            if (i < id.candidates.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.rank,
    required this.onTap,
  });

  final SpeciesCandidate candidate;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = (candidate.confidence * 100).round();
    final isLow = candidate.confidence < 0.5;
    return Material(
      color: rank == 1 ? surfaceBase : surfaceCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: rank == 1 ? gold : const Color(0xFFE8E0CE),
              width: rank == 1 ? 1.5 : 1,
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
                  color: rank == 1
                      ? gold
                      : const Color(0xFFE8E0CE),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: rank == 1 ? forestGreen : textSecondary,
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

/// Dialog déclenché quand on observe une espèce déjà connue mais non encore
/// curée pour la zone détectée par geocoding (ex: Merle noir présent en Oise
/// mais pas en Aisne avant cette obs). Demande la rareté locale, pré-remplie
/// avec celle d'une autre zone si dispo. Renvoie la rareté choisie via
/// Navigator.pop, ou null si l'utilisateur annule.
class _PickRarityForZoneDialog extends StatefulWidget {
  const _PickRarityForZoneDialog({
    required this.speciesCommonName,
    required this.zoneName,
    required this.initialRarity,
  });

  final String speciesCommonName;
  final String zoneName;
  final Rarity initialRarity;

  @override
  State<_PickRarityForZoneDialog> createState() =>
      _PickRarityForZoneDialogState();
}

class _PickRarityForZoneDialogState extends State<_PickRarityForZoneDialog> {
  late Rarity _selected = widget.initialRarity;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Première en ${widget.zoneName}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: forestGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${widget.speciesCommonName} n'est pas encore curé dans ce territoire. "
                "Choisis sa rareté locale pour l'ajouter au catalogue.",
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "RARETÉ DANS ${widget.zoneName.toUpperCase()}",
                style: GoogleFonts.karla(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<Rarity>(
                initialValue: _selected,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE8E0CE),
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
                    v != null ? setState(() => _selected = v) : null,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: () => Navigator.of(context).pop(_selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: forestGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
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

/// Dialog d'ajout d'une espèce au catalogue d'une zone.
/// Deux modes :
///   - Candidat IA fourni → nom et nom scientifique pré-remplis et figés ;
///     l'utilisateur ne choisit que catégorie + rareté (+ description/tips).
///   - Pas de candidat (saisie manuelle depuis le picker) → tous les champs
///     éditables. Cas d'une espèce vraiment nouvelle (jamais observée nulle
///     part) ; on demande tout pour qu'elle entre proprement dans le catalogue.
class _AddSpeciesDialog extends ConsumerStatefulWidget {
  const _AddSpeciesDialog({this.candidate, required this.zoneId});

  final SpeciesCandidate? candidate;
  final String zoneId;

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
  /// Initialisé sur la zone passée en param (généralement la zone détectée
  /// par geocoding), modifiable par l'user via les chips FilterChip.
  /// Insert species_zones se fait pour chacune avec la même rareté.
  late final Set<String> _selectedZoneIds = {widget.zoneId};

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
      final created = await ref.read(speciesRepositoryProvider).create(
            commonName: cn,
            scientificName: sn,
            categoryId: _selectedCategoryId!,
            description: desc,
            tips: tipsText,
            photoUrl: photoUrl,
          );
      // INSERT species_zones pour chaque territoire coché. Même rareté pour
      // tous (l'user peut ajuster par-zone plus tard via species_editor).
      final inserts = _selectedZoneIds
          .map((zid) => {
                'species_id': created.id,
                'zone_id': zid,
                'rarity': _selectedRarity.name,
              })
          .toList();
      await ref
          .read(supabaseClientProvider)
          .from('species_zones')
          .insert(inserts);
      if (mounted) Navigator.of(context).pop(created.id);
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

class _PlaceDisplay extends ConsumerWidget {
  const _PlaceDisplay({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geocodingAsync = ref.watch(
      reverseGeocodingProvider((lat: lat, lng: lng)),
    );
    return geocodingAsync.when(
      loading: () => Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Lecture du lieu…',
            style: GoogleFonts.karla(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: textSecondary,
            ),
          ),
        ],
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (result) {
        final name = result?.displayName;
        if (name == null) return const SizedBox.shrink();
        return Row(
          children: [
            const Icon(Icons.place_outlined, size: 14, color: terracotta),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: forestGreen,
                ),
              ),
            ),
          ],
        );
      },
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
        ? "Pas de GPS dans l'EXIF — défaut centre Oise"
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
              // picker avec l'id de l'espèce créée.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final newId = await showDialog<String>(
                      context: context,
                      builder: (_) => _AddSpeciesDialog(zoneId: widget.zoneId),
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

class _DiscoveryDialog extends StatelessWidget {
  const _DiscoveryDialog({
    required this.rarity,
    required this.points,
    required this.isFirst,
  });

  final Rarity rarity;
  final int points;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final color = switch (rarity) {
      Rarity.common => rarityCommon,
      Rarity.rare => rarityRare,
      Rarity.epic => rarityEpic,
      Rarity.legendary => rarityLegendary,
    };
    return Dialog(
      backgroundColor: surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 40,
                color: surfaceBase,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFirst ? 'Découverte !' : 'Marqueur ajouté',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: forestGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+ $points points',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: gold,
              ),
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
  }
}

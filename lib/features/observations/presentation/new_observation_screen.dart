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
import '../../../shared/models/app_user.dart';
import '../../../shared/models/category.dart' as model;
import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/providers/observer_provider.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/domain/points.dart';
import '../../species/data/species_identification_service.dart';
import '../../species/data/species_repository.dart';
import '../../species/data/species_with_rarity_provider.dart';
import '../../species/domain/species_identification.dart';
import '../../territories/data/category_repository.dart';
import '../../territories/data/geocoding_service.dart';
import '../../territories/data/territory_progress_provider.dart';
import '../data/observation_repository.dart';
import '../data/observations_for_map_provider.dart';
import '../data/observed_species_provider.dart';
import '../data/photo_picker_service.dart';
import '../data/photo_upload_service.dart';

/// Identification IA désactivée temporairement (Haiku 4.5 pas assez précis sur
/// la taxonomie ornithologique fine, ex: Grand Corbeau vs Corbeau freux).
/// À réactiver avec Sonnet 4.6 ou iNaturalist en post-MVP. Le code reste en
/// place — il suffit de remettre cette constante à true pour réactiver.
const _iaIdentificationEnabled = false;

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
      if (picked.latitude != null) _lat = picked.latitude;
      if (picked.longitude != null) _lng = picked.longitude;
      _identification = null;
      _suggestionDismissed = false;
      // IA active uniquement si feature flag ON et espèce pas verrouillée.
      _identifying = _iaIdentificationEnabled &&
          widget.preselectedSpeciesId == null;
    });
    if (_iaIdentificationEnabled && widget.preselectedSpeciesId == null) {
      unawaited(_runIdentification(picked.file));
    }
  }

  Future<void> _runIdentification(File file) async {
    // Contexte conditionnel selon les coords EXIF :
    //   - photo avec GPS dans Oise  → région + liste curée (gain max précision)
    //   - photo avec GPS hors Oise  → région seule (pas de liste curée trompeuse)
    //   - photo sans GPS            → aucun contexte (mieux que des biais faux)
    String? regionName;
    List<({String commonName, String scientificName})>? curated;

    if (_lat != null && _lng != null) {
      final geocoding = await ref
          .read(geocodingServiceProvider)
          .reverseGeocode(lat: _lat!, lng: _lng!);
      regionName = geocoding?.region;
      if (regionName == 'Oise') {
        final oise = await ref.read(oiseZoneProvider.future);
        final allSpecies = await ref.read(_zoneSpeciesProvider(oise.id).future);
        curated = allSpecies
            .map((s) => (
                  commonName: s.species.commonName,
                  scientificName: s.species.scientificName,
                ))
            .toList();
      }
    }

    final result = await ref
        .read(speciesIdentificationServiceProvider)
        .identifyFromFile(
          file,
          curatedSpecies: curated,
          regionName: regionName,
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
    final observerId = ref.read(currentObserverIdProvider);
    if (observerId == null) {
      setState(() => _error = 'Pas d\'observateur connecté.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final oise = await ref.read(oiseZoneProvider.future);
      final speciesId = _selectedSpeciesId!;
      final lat = _lat ?? 49.41; // centre approximatif Oise (fallback EXIF absent)
      final lng = _lng ?? 2.82;

      // Détection territoire — bloque si la position GPS n'est pas dans Oise.
      // Photo sans GPS → fallback Oise (l'utilisateur a accepté le défaut).
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
                  'Cette position est en « $country ». Seule l\'Oise (France) est curée pour le moment.';
            });
          }
          return;
        }

        // 3. En France mais hors Oise → bloque.
        if (region != null && region != 'Oise') {
          if (mounted) {
            setState(() {
              _submitting = false;
              _error =
                  'Cette position est en « $region ». Seule l\'Oise est curée. '
                  'Repositionne le marqueur sur la mini-carte ou choisis une autre photo.';
            });
          }
          return;
        }
      }

      // Rareté locale
      final rarityRow = await client
          .from('species_zones')
          .select('rarity')
          .eq('species_id', speciesId)
          .eq('zone_id', oise.id)
          .single();
      final rarity = Rarity.values
          .firstWhere((r) => r.name == (rarityRow['rarity'] as String));

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

      final pointsEarned = observationPoints(
        rarity: rarity,
        isFirst: isFirst,
        hasPhoto: photoUrl != null,
      );

      await ref.read(observationRepositoryProvider).create(
            userId: observerId,
            speciesId: speciesId,
            zoneId: oise.id,
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
      ref.invalidate(oiseProgressProvider);
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
    final observersAsync = ref.watch(observersProvider);
    final currentObserverId = ref.watch(currentObserverIdProvider);

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
            const SizedBox(height: 16),
            const _Label('Observateur'),
            const SizedBox(height: 6),
            _ObserverToggle(
              observersAsync: observersAsync,
              currentId: currentObserverId,
              onChanged: (id) => ref
                  .read(currentObserverIdProvider.notifier)
                  .setObserver(id),
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

class _AddSpeciesDialog extends ConsumerStatefulWidget {
  const _AddSpeciesDialog({required this.candidate, required this.zoneId});

  final SpeciesCandidate candidate;
  final String zoneId;

  @override
  ConsumerState<_AddSpeciesDialog> createState() => _AddSpeciesDialogState();
}

class _AddSpeciesDialogState extends ConsumerState<_AddSpeciesDialog> {
  String? _selectedCategoryId;
  late Rarity _selectedRarity;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedRarity = _rarityFromKey(widget.candidate.rarityKey);
  }

  Rarity _rarityFromKey(String key) {
    return Rarity.values.firstWhere(
      (r) => r.name == key,
      orElse: () => Rarity.common,
    );
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Choisis une catégorie.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final c = widget.candidate;
      final created = await ref.read(speciesRepositoryProvider).create(
            commonName: c.commonName,
            scientificName: c.scientificName,
            categoryId: _selectedCategoryId!,
          );
      // INSERT direct dans species_zones (pas de repo dédié au MVP).
      await ref.read(supabaseClientProvider).from('species_zones').insert({
        'species_id': created.id,
        'zone_id': widget.zoneId,
        'rarity': _selectedRarity.name,
      });
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
    final c = widget.candidate;
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
                'Ajouter cette espèce ?',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: forestGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Cette espèce n'est pas encore dans la liste de l'Oise.",
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),
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
                      c.commonName,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: forestGreen,
                      ),
                    ),
                    Text(
                      c.scientificName,
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
              Text(
                'CATÉGORIE',
                style: GoogleFonts.karla(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
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
                  // Pré-sélectionne la catégorie suggérée par l'IA si elle matche.
                  _selectedCategoryId ??= categories
                      .cast<model.Category?>()
                      .firstWhere(
                        (cat) => cat!.icon == c.categoryKey,
                        orElse: () => null,
                      )
                      ?.id;
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
              Text(
                'RARETÉ DANS L\'OISE',
                style: GoogleFonts.karla(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
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

  // Coords figées au mount — utilisées dans le viewport pour qu'il ne soit
  // pas re-appliqué à chaque rebuild parent (sinon le zoom user est reset
  // à chaque pan local, qui déclenche onMapIdle → setState parent → rebuild).
  // Pour recentrer après ce mount, on appelle _flyTo() explicitement.
  late final double _initialLat;
  late final double _initialLng;

  @override
  void initState() {
    super.initState();
    _initialLat = widget.lat;
    _initialLng = widget.lng;
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  }

  // didUpdateWidget retiré : provoquait un flyTo à chaque pan/zoom (round-trip
  // _onMapIdle → setState parent → rebuild → didUpdateWidget → flyTo qui
  // réinitialisait le zoom). Le recentrage explicite (retour fullscreen,
  // bouton "ma position") est désormais fait directement via _flyTo().

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
    widget.onPositionChanged((lat: pos.lat.toDouble(), lng: pos.lng.toDouble()));
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
              viewport: CameraViewportState(
                center: Point(coordinates: Position(_initialLng, _initialLat)),
                zoom: 11,
              ),
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

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
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
            viewport: CameraViewportState(
              center:
                  Point(coordinates: Position(widget.initialLng, widget.initialLat)),
              zoom: 12,
            ),
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

class _ObserverToggle extends StatelessWidget {
  const _ObserverToggle({
    required this.observersAsync,
    required this.currentId,
    required this.onChanged,
  });

  final AsyncValue<List<AppUser>> observersAsync;
  final String? currentId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return observersAsync.when(
      loading: () => const SizedBox(height: 50),
      error: (e, _) => Text(
        'Observateurs indisponibles',
        style: GoogleFonts.karla(color: textMuted),
      ),
      data: (users) => Row(
        children: [
          for (var i = 0; i < users.length; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(users[i].id),
                child: _observerChip(users[i], users[i].id == currentId),
              ),
            ),
            if (i != users.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _observerChip(AppUser u, bool selected) {
    final color = Color(int.parse(u.colorAccent.replaceFirst('#', '0xFF')));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color : surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? color : const Color(0xFFE8E0CE),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          u.pseudo,
          style: GoogleFonts.karla(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? surfaceBase : textPrimary,
          ),
        ),
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

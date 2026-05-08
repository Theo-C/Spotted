import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/providers/observer_provider.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../gamification/data/gamification_providers.dart';
import '../../gamification/domain/points.dart';
import '../../species/data/species_repository.dart';
import '../../territories/data/territory_progress_provider.dart';
import '../data/observation_repository.dart';
import '../data/observed_species_provider.dart';
import '../data/photo_picker_service.dart';
import '../data/photo_upload_service.dart';

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
    });
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
      final lat = _lat ?? 49.41; // centre approximatif Oise
      final lng = _lng ?? 2.82;

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
            const SizedBox(height: 20),
            const _Label('Date'),
            const SizedBox(height: 6),
            _ReadOnlyField(
              text: DateFormat('d MMMM yyyy', 'fr').format(_observedAt),
              icon: Icons.calendar_today,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            const _Label('Coordonnées'),
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

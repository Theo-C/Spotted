import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/category.dart' as model;
import '../../../shared/models/rarity.dart';
import '../../../shared/models/species.dart';
import '../../../shared/models/species_reference.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../observations/data/photo_picker_service.dart';
import '../../observations/data/photo_upload_service.dart';
import '../../territories/data/category_repository.dart';
import '../../territories/data/territory_progress_provider.dart';
import '../data/species_detail_provider.dart';
import '../data/species_repository.dart';
import '../data/species_with_rarity_provider.dart';
import 'multi_zone_selector.dart';
import 'species_photo_picker.dart';
import 'species_reference_autocomplete.dart';

/// Écran d'ajout / édition d'une espèce dans le catalogue.
/// - [speciesId] null → création
/// - [speciesId] présent → édition (champs pré-remplis, scientific_name immuable,
///   rareté Oise verrouillée si l'espèce a déjà des observations validées)
class SpeciesEditorScreen extends ConsumerStatefulWidget {
  const SpeciesEditorScreen({super.key, this.speciesId});

  final String? speciesId;

  @override
  ConsumerState<SpeciesEditorScreen> createState() =>
      _SpeciesEditorScreenState();
}

class _SpeciesEditorScreenState extends ConsumerState<SpeciesEditorScreen> {
  final _commonName = TextEditingController();
  final _scientificName = TextEditingController();
  final _description = TextEditingController();
  final _tips = TextEditingController();
  String? _selectedCategoryId;
  Rarity _selectedRarity = Rarity.common;
  bool _submitting = false;
  bool _initialized = false;
  String? _error;

  /// Photo locale fraîchement sélectionnée par l'user (à uploader au submit).
  /// Null si l'user n'a rien changé : on garde alors [_existingPhotoUrl].
  File? _pickedPhoto;

  /// URL d'une photo déjà uploadée pour cette espèce (mode édition seulement,
  /// ou pré-remplie depuis species_reference en création).
  String? _existingPhotoUrl;

  /// Category key pré-sélectionnée depuis species_reference après autocomplete.
  /// Utilisée pour matcher avec la categories list au build.
  String? _refCategoryKey;

  /// Zone IDs auxquelles l'espèce sera liée à la création (chips Multi).
  /// Pré-rempli avec Oise par défaut au prochain frame (cf. initState).
  final Set<String> _selectedZoneIds = {};

  bool get _isEditing => widget.speciesId != null;

  @override
  void initState() {
    super.initState();
    // En création, pré-sélectionne Oise comme territoire par défaut.
    // L'user peut le décocher et/ou cocher Aisne ou d'autres zones.
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final oise = await ref.read(oiseZoneProvider.future);
        if (mounted && _selectedZoneIds.isEmpty) {
          setState(() => _selectedZoneIds.add(oise.id));
        }
      });
    }
  }

  /// Pré-remplit le formulaire depuis une entrée species_reference
  /// sélectionnée via l'autocomplete. commonName est déjà rempli (par
  /// le controller piloté par RawAutocomplete) — on remplit le reste.
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
      _selectedCategoryId = null; // forcera la re-dérivation depuis _refCategoryKey
    });
  }

  @override
  void dispose() {
    _commonName.dispose();
    _scientificName.dispose();
    _description.dispose();
    _tips.dispose();
    super.dispose();
  }

  Future<void> _initFromExisting() async {
    if (_initialized || widget.speciesId == null) return;
    _initialized = true;
    final oise = await ref.read(oiseZoneProvider.future);
    final detail = await ref.read(
      speciesDetailProvider(
        (zoneId: oise.id, speciesId: widget.speciesId!),
      ).future,
    );
    if (!mounted) return;
    setState(() {
      _commonName.text = detail.species.commonName;
      _scientificName.text = detail.species.scientificName;
      _description.text = detail.species.description ?? '';
      _tips.text = detail.species.tips ?? '';
      _selectedCategoryId = detail.species.categoryId;
      _selectedRarity = detail.rarity;
      _existingPhotoUrl = detail.species.photoUrl;
    });
  }

  Future<void> _pickPhoto() async {
    final picked =
        await ref.read(photoPickerServiceProvider).pickFromGallery();
    if (picked == null || !mounted) return;
    setState(() {
      _pickedPhoto = picked.file;
    });
  }

  void _removePhoto() {
    setState(() {
      _pickedPhoto = null;
      _existingPhotoUrl = null;
    });
  }

  Future<void> _submit({required bool rarityLocked}) async {
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
    if (!_isEditing && _selectedZoneIds.isEmpty) {
      setState(() => _error = 'Choisis au moins un territoire.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final oise = await ref.read(oiseZoneProvider.future);
      final client = ref.read(supabaseClientProvider);
      final desc =
          _description.text.trim().isEmpty ? null : _description.text.trim();
      final tipsText =
          _tips.text.trim().isEmpty ? null : _tips.text.trim();

      // Si l'user a sélectionné une nouvelle photo, on l'upload et on
      // récupère l'URL publique. Sinon on garde l'éventuelle URL existante
      // (qu'il aura pu mettre à null en cliquant sur "retirer").
      String? photoUrl = _existingPhotoUrl;
      if (_pickedPhoto != null) {
        final uploaderId = ref.read(currentAuthUserProvider)?.id;
        if (uploaderId != null) {
          photoUrl =
              await ref.read(photoUploadServiceProvider).uploadSpeciesPhoto(
                    file: _pickedPhoto!,
                    uploaderUserId: uploaderId,
                  );
        }
      }

      String speciesId;
      if (_isEditing) {
        // UPDATE de l'espèce existante.
        final original = await ref
            .read(speciesRepositoryProvider)
            .getById(widget.speciesId!);
        final updated = await ref.read(speciesRepositoryProvider).update(
              Species(
                id: original.id,
                commonName: cn,
                scientificName: sn,
                categoryId: _selectedCategoryId!,
                description: desc,
                tips: tipsText,
                photoUrl: photoUrl,
                createdByUserId: original.createdByUserId,
                createdAt: original.createdAt,
              ),
            );
        speciesId = updated.id;
        if (!rarityLocked) {
          await client
              .from('species_zones')
              .update({'rarity': _selectedRarity.name})
              .eq('species_id', speciesId)
              .eq('zone_id', oise.id);
        }
      } else {
        // CREATE ou LINK selon si l'espèce existe déjà au catalogue.
        // Si oui (typiquement : Lanius collurio déjà dans Oise, user veut
        // l'ajouter à Aisne), on ne re-crée pas — on ajoute simplement les
        // liens species_zones manquants. Description / tips / photo de
        // l'espèce d'origine ne sont pas écrasés (fields immuables une fois
        // au catalogue, cohérent avec le mode édition qui verrouille aussi).
        final repo = ref.read(speciesRepositoryProvider);
        final existing = await repo.getByScientificName(sn);
        if (existing != null) {
          final alreadyLinked = await repo.getZoneIdsForSpecies(existing.id);
          final toAdd = _selectedZoneIds.difference(alreadyLinked);
          if (toAdd.isEmpty) {
            setState(() {
              _submitting = false;
              _error =
                  "Cette espèce est déjà présente sur tous les territoires cochés.";
            });
            return;
          }
          final inserts = toAdd
              .map((zid) => {
                    'species_id': existing.id,
                    'zone_id': zid,
                    'rarity': _selectedRarity.name,
                  })
              .toList();
          await client.from('species_zones').insert(inserts);
          speciesId = existing.id;
        } else {
          final created = await ref.read(speciesRepositoryProvider).create(
                commonName: cn,
                scientificName: sn,
                categoryId: _selectedCategoryId!,
                description: desc,
                tips: tipsText,
                photoUrl: photoUrl,
              );
          speciesId = created.id;
          final inserts = _selectedZoneIds
              .map((zid) => {
                    'species_id': speciesId,
                    'zone_id': zid,
                    'rarity': _selectedRarity.name,
                  })
              .toList();
          await client.from('species_zones').insert(inserts);
        }
      }

      // Invalide les caches qui dépendent du catalogue.
      ref.invalidate(speciesByCategoryInZoneProvider);
      ref.invalidate(categoriesWithProgressProvider);
      if (_isEditing) {
        ref.invalidate(speciesDetailProvider);
      }

      if (mounted) {
        if (_isEditing) {
          context.pop();
        } else {
          // Navigue vers la fiche détail dans le 1er territoire coché (Oise
          // si elle est cochée, sinon le 1er de la liste — l'ordre est
          // stable car Set préserve l'ordre d'insertion en Dart).
          final firstZone = _selectedZoneIds.contains(oise.id)
              ? oise.id
              : _selectedZoneIds.first;
          context.go(
            '/territory/$firstZone/category/${_selectedCategoryId!}/species/$speciesId',
          );
        }
      }
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
    final hasObsAsync = _isEditing
        ? ref.watch(_hasObservationsProvider(widget.speciesId!))
        : const AsyncValue<bool>.data(false);

    // Mode édition : pré-rempli au premier build.
    if (_isEditing && !_initialized) {
      _initFromExisting();
    }

    final rarityLocked = hasObsAsync.asData?.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? "Modifier l'espèce" : 'Nouvelle espèce',
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
            _Label(_isEditing ? 'Nom commun' : 'Espèce'),
            const SizedBox(height: 6),
            if (_isEditing)
              _TextInput(
                controller: _commonName,
                hint: 'Ex : Buse variable',
                textInputAction: TextInputAction.next,
                readOnly: true,
              )
            else ...[
              SpeciesReferenceAutocomplete(
                controller: _commonName,
                onSelected: _applyReferenceSelection,
              ),
              const SizedBox(height: 6),
              Text(
                "Tape le nom commun, sélectionne dans la liste : tous les "
                "champs se remplissent. Si l'espèce n'est pas dans la banque, "
                "remplis manuellement le reste.",
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _Label('Nom scientifique'),
            const SizedBox(height: 6),
            _TextInput(
              controller: _scientificName,
              hint: 'Ex : Buteo buteo',
              italic: true,
              textInputAction: TextInputAction.next,
              readOnly: _isEditing,
            ),
            if (_isEditing) ...[
              const SizedBox(height: 4),
              Text(
                'Les noms ne peuvent pas être modifiés en édition. Tu peux ajuster catégorie, rareté, description et conseil terrain.',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: textMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _Label('Catégorie'),
            const SizedBox(height: 6),
            categoriesAsync.when(
              loading: () => const SizedBox(height: 56),
              error: (e, _) => Text(
                'Catégories indisponibles',
                style: GoogleFonts.karla(color: textMuted),
              ),
              data: (cats) {
                // En création, pré-sélectionne la catégorie depuis
                // species_reference si une espèce a été choisie via l'autocomplete.
                if (!_isEditing && _refCategoryKey != null) {
                  _selectedCategoryId ??= cats
                      .cast<model.Category?>()
                      .firstWhere(
                        (c) => c!.icon == _refCategoryKey,
                        orElse: () => null,
                      )
                      ?.id;
                }
                return _CategoryPicker(
                  categories: cats,
                  selectedId: _selectedCategoryId,
                  onChanged: (id) =>
                      setState(() => _selectedCategoryId = id),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Label(_isEditing ? "Rareté dans l'Oise" : 'Rareté'),
                if (rarityLocked) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_outline,
                      size: 12, color: terracotta),
                ],
              ],
            ),
            const SizedBox(height: 6),
            _RarityPicker(
              selected: _selectedRarity,
              locked: rarityLocked,
              onChanged: rarityLocked
                  ? null
                  : (r) => setState(() => _selectedRarity = r),
            ),
            if (rarityLocked) ...[
              const SizedBox(height: 4),
              Text(
                "Rareté verrouillée — l'espèce a déjà été observée sur ce territoire.",
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: textMuted,
                ),
              ),
            ],
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              const _Label('Territoires'),
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
                "Coche les territoires où l'espèce est présente. La rareté "
                "ci-dessus s'applique aux territoires cochés (modifiable par "
                "territoire plus tard via l'édition).",
                style: GoogleFonts.karla(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _Label('Description (optionnelle)'),
            const SizedBox(height: 6),
            _TextInput(
              controller: _description,
              hint: 'Habitat, comportement, signes distinctifs…',
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            const _Label('Pour la débusquer (conseil terrain)'),
            const SizedBox(height: 6),
            _TextInput(
              controller: _tips,
              hint: 'Où, quand, comment chercher cette espèce sur le terrain…',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const _Label('Photo d\'illustration (optionnelle)'),
            const SizedBox(height: 6),
            SpeciesPhotoPicker(
              pickedFile: _pickedPhoto,
              existingUrl: _existingPhotoUrl,
              onPick: _pickPhoto,
              onRemove: _removePhoto,
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
              onPressed: _submitting
                  ? null
                  : () => _submit(rarityLocked: rarityLocked),
              style: FilledButton.styleFrom(
                backgroundColor: forestGreen,
                foregroundColor: surfaceBase,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
                      _isEditing
                          ? 'METTRE À JOUR'
                          : 'AJOUTER AU CATALOGUE',
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

final _categoriesProvider = FutureProvider<List<model.Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getAll();
});

/// True s'il y a au moins une observation pour cette espèce dans Oise.
/// Sert à verrouiller la rareté en mode édition (CDC §règles métier).
final _hasObservationsProvider =
    FutureProvider.family<bool, String>((ref, speciesId) async {
  final oise = await ref.watch(oiseZoneProvider.future);
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('observations')
      .select('id')
      .eq('species_id', speciesId)
      .eq('zone_id', oise.id)
      .limit(1);
  return (rows as List).isNotEmpty;
});

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

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.hint,
    this.italic = false,
    this.maxLines = 1,
    this.textInputAction,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool italic;
  final int maxLines;
  final TextInputAction? textInputAction;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? surfaceMuted : surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        textInputAction: textInputAction,
        maxLines: maxLines,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 16,
          color: readOnly ? textSecondary : textPrimary,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
        cursorColor: forestGreen,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cormorantGaramond(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: textMuted,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final List<model.Category> categories;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in categories)
          GestureDetector(
            onTap: () => onChanged(c.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selectedId == c.id ? forestGreen : surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedId == c.id
                      ? forestGreen
                      : const Color(0xFFE8E0CE),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emojiForCategory(c.icon),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.name,
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selectedId == c.id ? surfaceBase : forestGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RarityPicker extends StatelessWidget {
  const _RarityPicker({
    required this.selected,
    required this.onChanged,
    this.locked = false,
  });

  final Rarity selected;
  final ValueChanged<Rarity>? onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: Row(
        children: [
          for (final r in Rarity.values) ...[
            Expanded(
              child: GestureDetector(
                onTap: onChanged == null ? null : () => onChanged!(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == r
                        ? _color(r)
                        : _color(r).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _color(r),
                      width: selected == r ? 1.8 : 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _label(r).toUpperCase(),
                    style: GoogleFonts.karla(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: selected == r ? surfaceBase : _color(r),
                    ),
                  ),
                ),
              ),
            ),
            if (r != Rarity.values.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  static String _label(Rarity r) => switch (r) {
        Rarity.common => 'Commun',
        Rarity.rare => 'Rare',
        Rarity.epic => 'Épique',
        Rarity.legendary => 'Légend.',
      };

  static Color _color(Rarity r) => switch (r) {
        Rarity.common => rarityCommon,
        Rarity.rare => rarityRare,
        Rarity.epic => rarityEpic,
        Rarity.legendary => rarityLegendary,
      };
}


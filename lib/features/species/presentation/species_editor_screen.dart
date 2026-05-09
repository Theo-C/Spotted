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
import '../../../shared/providers/supabase_client_provider.dart';
import '../../territories/data/category_repository.dart';
import '../../territories/data/territory_progress_provider.dart';
import '../data/species_detail_provider.dart';
import '../data/species_repository.dart';
import '../data/species_with_rarity_provider.dart';

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
  String? _selectedCategoryId;
  Rarity _selectedRarity = Rarity.common;
  bool _submitting = false;
  bool _initialized = false;
  String? _error;

  bool get _isEditing => widget.speciesId != null;

  @override
  void dispose() {
    _commonName.dispose();
    _scientificName.dispose();
    _description.dispose();
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
      _selectedCategoryId = detail.species.categoryId;
      _selectedRarity = detail.rarity;
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
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final oise = await ref.read(oiseZoneProvider.future);
      final client = ref.read(supabaseClientProvider);
      final desc =
          _description.text.trim().isEmpty ? null : _description.text.trim();

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
                photoUrl: original.photoUrl,
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
        // CREATE
        final created = await ref.read(speciesRepositoryProvider).create(
              commonName: cn,
              scientificName: sn,
              categoryId: _selectedCategoryId!,
              description: desc,
            );
        speciesId = created.id;
        await client.from('species_zones').insert({
          'species_id': speciesId,
          'zone_id': oise.id,
          'rarity': _selectedRarity.name,
        });
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
          context.go(
            '/territory/${oise.id}/category/${_selectedCategoryId!}/species/$speciesId',
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
            const _Label('Nom commun'),
            const SizedBox(height: 6),
            _TextInput(
              controller: _commonName,
              hint: 'Ex : Buse variable',
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              readOnly: _isEditing,
            ),
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
                'Les noms ne peuvent pas être modifiés en édition. Tu peux ajuster catégorie, rareté et description.',
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
              data: (cats) => _CategoryPicker(
                categories: cats,
                selectedId: _selectedCategoryId,
                onChanged: (id) => setState(() => _selectedCategoryId = id),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const _Label('Rareté dans l\'Oise'),
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
            const SizedBox(height: 16),
            const _Label('Description (optionnelle)'),
            const SizedBox(height: 6),
            _TextInput(
              controller: _description,
              hint: 'Habitat, comportement, signes distinctifs…',
              maxLines: 4,
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
    this.autofocus = false,
    this.textInputAction,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool italic;
  final int maxLines;
  final bool autofocus;
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
        autofocus: autofocus,
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

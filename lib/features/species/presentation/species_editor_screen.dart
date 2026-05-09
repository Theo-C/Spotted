import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../../../shared/models/category.dart' as model;
import '../../../shared/models/rarity.dart';
import '../../../shared/providers/supabase_client_provider.dart';
import '../../territories/data/category_repository.dart';
import '../../territories/data/territory_progress_provider.dart';
import '../data/species_repository.dart';
import '../data/species_with_rarity_provider.dart';

/// Écran de création d'une nouvelle espèce dans le catalogue.
/// L'édition (mode pré-rempli + cadenas rareté) sera ajoutée Phase 8.C.
class SpeciesEditorScreen extends ConsumerStatefulWidget {
  const SpeciesEditorScreen({super.key});

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
  String? _error;

  @override
  void dispose() {
    _commonName.dispose();
    _scientificName.dispose();
    _description.dispose();
    super.dispose();
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
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final oise = await ref.read(oiseZoneProvider.future);
      final created = await ref.read(speciesRepositoryProvider).create(
            commonName: cn,
            scientificName: sn,
            categoryId: _selectedCategoryId!,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
          );
      await ref.read(supabaseClientProvider).from('species_zones').insert({
        'species_id': created.id,
        'zone_id': oise.id,
        'rarity': _selectedRarity.name,
      });

      // Invalide les providers qui consomment la liste des espèces.
      ref.invalidate(speciesByCategoryInZoneProvider);
      ref.invalidate(categoriesWithProgressProvider);

      if (mounted) {
        // Redirige sur la fiche de l'espèce nouvellement créée.
        context.go(
          '/territory/${oise.id}/category/${_selectedCategoryId!}/species/${created.id}',
        );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nouvelle espèce',
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
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const _Label('Nom scientifique'),
            const SizedBox(height: 6),
            _TextInput(
              controller: _scientificName,
              hint: 'Ex : Buteo buteo',
              italic: true,
              textInputAction: TextInputAction.next,
            ),
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
            const _Label('Rareté dans l\'Oise'),
            const SizedBox(height: 6),
            _RarityPicker(
              selected: _selectedRarity,
              onChanged: (r) => setState(() => _selectedRarity = r),
            ),
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
              onPressed: _submitting ? null : _submit,
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
                      'AJOUTER AU CATALOGUE',
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
  });

  final TextEditingController controller;
  final String hint;
  final bool italic;
  final int maxLines;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textInputAction: textInputAction,
        maxLines: maxLines,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 16,
          color: textPrimary,
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
  const _RarityPicker({required this.selected, required this.onChanged});

  final Rarity selected;
  final ValueChanged<Rarity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final r in Rarity.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(r),
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

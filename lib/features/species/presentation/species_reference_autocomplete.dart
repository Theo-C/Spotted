import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/species_reference.dart';
import '../data/species_reference_repository.dart';

/// Autocomplete partagé sur la table `species_reference` pour la saisie
/// du nom commun d'une espèce. Cherche en ilike sur common_name OU
/// scientific_name (insensible à la casse), affiche un dropdown avec les
/// candidats (nom commun en gros, nom scientifique italique).
///
/// Utilisé par :
///  - `_AddSpeciesDialog` (form d'obs → bouton "+ Ajouter espèce")
///  - `species_editor_screen` (Home → + → Nouvelle espèce)
///
/// L'écran parent fournit son propre TextEditingController (généralement
/// celui qui pilote le champ "nom commun" de son formulaire) et reçoit la
/// sélection via [onSelected] pour pré-remplir les autres champs.
class SpeciesReferenceAutocomplete extends ConsumerStatefulWidget {
  const SpeciesReferenceAutocomplete({
    super.key,
    required this.controller,
    required this.onSelected,
    this.hintText = 'Tape pour chercher (ex: buse, mésange, sanglier…)',
  });

  final TextEditingController controller;
  final void Function(SpeciesReference) onSelected;
  final String hintText;

  @override
  ConsumerState<SpeciesReferenceAutocomplete> createState() =>
      _SpeciesReferenceAutocompleteState();
}

class _SpeciesReferenceAutocompleteState
    extends ConsumerState<SpeciesReferenceAutocomplete> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<SpeciesReference>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.commonName,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text;
        if (query.trim().length < 2) {
          return const Iterable<SpeciesReference>.empty();
        }
        try {
          return await ref
              .read(speciesReferenceRepositoryProvider)
              .search(query);
        } catch (_) {
          return const Iterable<SpeciesReference>.empty();
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: GoogleFonts.karla(fontSize: 13, color: textMuted),
            prefixIcon: const Icon(Icons.search, size: 18, color: forestGreen),
            filled: true,
            fillColor: surfaceCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE8E0CE),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE8E0CE),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: forestGreen, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelectedCallback(option),
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
                            option.commonName,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: forestGreen,
                            ),
                          ),
                          Text(
                            option.scientificName,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: terracotta,
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
      onSelected: widget.onSelected,
    );
  }
}

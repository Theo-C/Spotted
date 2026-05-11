import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Slot photo réutilisable pour l'illustration d'une espèce.
/// Utilisé dans species_editor_screen (édition / création détaillée) et dans
/// le dialog inline _AddSpeciesDialog du formulaire d'observation.
///
/// Trois états visuels :
///   - aucune photo (rien sélectionné, pas d'URL existante) → CTA "Choisir
///     une photo".
///   - photo locale fraîchement pickée → preview du fichier + lien "Retirer".
///   - URL distante (édition d'une espèce qui a déjà sa photo) → preview
///     network + lien "Retirer". Cliquer sur le slot remplace la photo.
///
/// Le widget ne gère pas l'upload ni l'état — il expose les callbacks
/// `onPick` et `onRemove` que l'écran parent câble.
class SpeciesPhotoPicker extends StatelessWidget {
  const SpeciesPhotoPicker({
    super.key,
    required this.pickedFile,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
    this.height = 180,
  });

  final File? pickedFile;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  /// Hauteur du slot. 180 par défaut pour un écran ; passer ~120 pour un dialog.
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = pickedFile != null || existingUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasPhoto ? forestGreen : const Color(0xFFC4A572),
                width: 2,
              ),
              // contain plutôt que cover : on veut toujours voir l'animal en
              // entier, même si la photo est portrait sur un slot paysage.
              // Le surfaceCard derrière (cf. color) reste visible en bandes.
              image: pickedFile != null
                  ? DecorationImage(
                      image: FileImage(pickedFile!),
                      fit: BoxFit.contain,
                    )
                  : (existingUrl != null
                      ? DecorationImage(
                          image: NetworkImage(existingUrl!),
                          fit: BoxFit.contain,
                        )
                      : null),
            ),
            child: hasPhoto
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
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
                        'Une seule photo, illustration du catalogue',
                        style: GoogleFonts.karla(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 14, color: terracotta),
                label: Text(
                  'Retirer',
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: terracotta,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// Widgets partagés pour les 3 états async classiques : loading, error, empty.
///
/// Avant : chaque écran roulait son propre pattern (CircularProgressIndicator
/// standard, container custom, ou skeleton bricolé). Résultat : incohérence
/// visuelle et duplication. Ici on centralise avec un design cohérent charte
/// naturaliste (crème + forestGreen + gold accents).
///
/// Usage typique dans `AsyncValue.when` :
/// ```dart
/// asyncValue.when(
///   loading: () => const LoadingState(),
///   error: (e, _) => const ErrorState(message: 'Chargement impossible'),
///   data: (items) => items.isEmpty
///       ? const EmptyState(emoji: '🐾', message: 'Aucune observation')
///       : MyListWidget(items: items),
/// )
/// ```

/// Loading centré discret — spinner forestGreen sur fond transparent, avec
/// une hauteur minimale pour éviter les sauts de layout entre loading et data.
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.height = 120,
    this.label,
  });

  /// Hauteur minimale du conteneur (évite les jumps).
  final double height;

  /// Texte optionnel sous le spinner — inutile pour un loading rapide.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: forestGreen,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 10),
              Text(
                label!.toUpperCase(),
                style: GoogleFonts.karla(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Erreur discrète — icône terracotta + message. Pas de bouton retry par
/// défaut (l'invalidation vient généralement de l'écran parent).
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.message = 'Chargement impossible.',
    this.onRetry,
  });

  final String message;

  /// Si fourni, affiche un petit bouton "Réessayer" sous le message.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: terracotta, size: 28),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.karla(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Réessayer',
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: terracotta,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// État vide avec emoji au choix — pour donner du caractère naturaliste
/// aux messages "aucune obs / aucun badge / aucune espèce". Pas de bouton
/// action par défaut (contexte-dépendant).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.emoji = '🐾',
    required this.message,
    this.subtitle,
  });

  final String emoji;
  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: forestGreen,
                height: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

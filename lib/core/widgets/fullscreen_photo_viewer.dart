import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Ouvre [url] en plein écran zoomable/pannable via un push top-level.
///
/// UX :
///   - Fade-in du fond noir (200 ms)
///   - Photo centrée en `contain` avec `InteractiveViewer` (zoom 1×→5× + pan)
///   - Tap fond OU bouton × en haut-droit → pop
///
/// Usage typique : sur tap d'une photo dans un sheet, une card, ou un hero.
/// Utilise `rootNavigator: true` pour couvrir toute l'app même quand
/// l'appelant est dans un bottom sheet (sinon la photo serait limitée à
/// la zone du sheet).
void openFullscreenPhoto(BuildContext context, String url) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      pageBuilder: (context, _, _) => _FullscreenPhotoViewer(url: url),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 200),
    ),
  );
}

class _FullscreenPhotoViewer extends StatelessWidget {
  const _FullscreenPhotoViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: gold,
                        ),
                      ),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: textMuted,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: surfaceBase.withValues(alpha: 0.95),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.close, color: forestGreen),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/services/notifications_service.dart';

/// Dialog d'opt-in pour le rappel quotidien de série, montrée 1x au démarrage
/// après login (cf. _StreakOptInGate dans home_screen). L'user choisit "Oui
/// active" ou "Plus tard". Dans les deux cas on persiste qu'on l'a montrée.
class StreakOptInDialog extends ConsumerStatefulWidget {
  const StreakOptInDialog({super.key});

  @override
  ConsumerState<StreakOptInDialog> createState() => _StreakOptInDialogState();

  /// Décide d'afficher ou non la dialog. Appelé depuis la home après
  /// 1ʳᵉ frame.  Persiste l'état "vu" dans tous les cas pour ne pas spammer.
  static Future<void> showIfNeeded(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final shouldShow =
        await ref.read(notificationsOptInPromptProvider.future);
    if (!shouldShow || !context.mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => const StreakOptInDialog(),
    );
    await ref
        .read(notificationsServiceProvider)
        .markOptInPromptShown();
    ref.invalidate(notificationsOptInPromptProvider);
    ref.invalidate(notificationsEnabledProvider);
  }
}

class _StreakOptInDialogState extends ConsumerState<StreakOptInDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Garde ta flamme allumée',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: forestGreen,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        "Activer un petit rappel à 20:00 chaque jour, pour ne pas casser ta "
        "série quand tu oublies. Tu peux changer d'avis à tout moment dans le Profil.",
        style: GoogleFonts.karla(
          fontSize: 13,
          color: textPrimary,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Plus tard',
            style: GoogleFonts.karla(color: textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _onEnable,
          style: FilledButton.styleFrom(backgroundColor: forestGreen),
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: surfaceBase,
                  ),
                )
              : Text(
                  'Activer',
                  style: GoogleFonts.karla(
                    fontWeight: FontWeight.bold,
                    color: surfaceBase,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _onEnable() async {
    setState(() => _busy = true);
    final ok = await ref.read(notificationsServiceProvider).enable();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: terracotta,
          content: Text(
            "Permission refusée — tu peux l'autoriser dans les réglages système.",
            style: GoogleFonts.karla(color: surfaceBase),
          ),
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../data/auth_providers.dart';
import '../data/user_repository.dart';

/// Écran de setup profil — affiché après le 1er signup (Google ou Magic
/// Link). L'user choisit son pseudo + une couleur accent (utilisée pour
/// le level card + les pastilles observer sur la Carte).
///
/// Le trigger DB `handle_new_auth_user` a déjà créé une ligne public.users
/// avec un pseudo par défaut (préfixe email) et `profile_completed = false`.
/// Cet écran fait le UPDATE et flip le flag → router laisse passer vers Home.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _pseudoController = TextEditingController();
  String _selectedColor = _palette.first;
  bool _submitting = false;
  String? _error;
  bool _initialized = false;

  /// Palette limitée mais harmonieuse avec la charte de l'app. On évite le
  /// full color picker (mauvaise UX naturaliste "carnet vintage") au profit
  /// d'une sélection curated.
  static const List<String> _palette = [
    '#1F3D2E', // forestGreen (défaut)
    '#B8624A', // terracotta
    '#C49120', // gold
    '#2D6E8C', // rare (bleu)
    '#7A3D9A', // epic (violet)
    '#6B8E23', // olive drab
    '#8B4513', // saddle brown
    '#5F9EA0', // cadet blue
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Préremplit le pseudo avec la valeur par défaut (préfixe email) au
    // 1er render — permet à l'user de valider tel quel s'il aime bien.
    if (_initialized) return;
    final appUser = ref.read(currentAppUserProvider).asData?.value;
    if (appUser != null) {
      _pseudoController.text = appUser.pseudo;
      _selectedColor =
          _palette.contains(appUser.colorAccent)
              ? appUser.colorAccent
              : _palette.first;
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pseudo = _pseudoController.text.trim();
    if (pseudo.length < 2) {
      setState(() => _error = 'Ton pseudo fait au moins 2 caractères.');
      return;
    }
    if (pseudo.length > 24) {
      setState(() => _error = 'Ton pseudo est trop long (24 max).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = ref.read(currentAuthUserProvider)?.id;
      if (userId == null) throw StateError('Pas connecté');
      await ref.read(userRepositoryProvider).completeProfile(
            userId: userId,
            pseudo: pseudo,
            colorAccent: _selectedColor,
          );
      // Invalidate → currentAppUserProvider recharge avec profileCompleted=true
      // → router redirect vers /tuto ou / selon état onboarding.
      ref.invalidate(currentAppUserProvider);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Impossible d'enregistrer. Réessaie.");
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Text('🐾', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(
                'Bienvenue dans Spotted',
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: forestGreen,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'On te connaît sous quel nom ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.karla(
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              _buildPseudoField(),
              const SizedBox(height: 28),
              _buildColorSection(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    color: terracotta,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPseudoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TON PSEUDO',
          style: GoogleFonts.karla(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE8E0CE),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _pseudoController,
            enabled: !_submitting,
            autofocus: true,
            maxLength: 24,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              color: forestGreen,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: terracotta,
            decoration: InputDecoration(
              hintText: 'ex: LeChasseurDesBois',
              hintStyle: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                color: textMuted,
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TA COULEUR',
          style: GoogleFonts.karla(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Utilisée pour tes pastilles sur la carte et ton profil.',
          style: GoogleFonts.karla(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in _palette)
              _ColorDot(
                hex: hex,
                selected: hex == _selectedColor,
                onTap: () => setState(() => _selectedColor = hex),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _submitting ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: forestGreen,
        foregroundColor: surfaceBase,
        disabledBackgroundColor: forestGreen.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              "C'EST PARTI !",
              style: GoogleFonts.karla(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? forestGreen : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: selected
            ? const Icon(Icons.check, color: surfaceBase, size: 22)
            : null,
      ),
    );
  }
}

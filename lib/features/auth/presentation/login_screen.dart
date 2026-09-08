import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../data/auth_repository.dart';

/// Écran de login — auth passwordless via Magic Link email.
///
/// Google OAuth est câblé dans [AuthRepository.signInWithGoogle] mais pas
/// exposé dans l'UI pour l'instant (nécessite un setup Google Cloud +
/// Supabase Dashboard qui n'est pas encore fait). Réactiver ici quand la
/// config est prête — un bouton "Continuer avec Google" au-dessus de
/// l'email suffit.
///
/// Volontairement sans champ mot de passe : les comptes historiques
/// (créés manuellement avant l'ouverture) basculent en Magic Link via
/// leur email existant, aucune migration manuelle nécessaire.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  bool _isSendingLink = false;
  String? _errorMessage;
  bool _linkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Email invalide.');
      return;
    }
    setState(() {
      _isSendingLink = true;
      _errorMessage = null;
      _linkSent = false;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithMagicLink(email);
      if (mounted) setState(() => _linkSent = true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _translateError(e.message));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Envoi impossible. Réessaie.');
      }
    } finally {
      if (mounted) setState(() => _isSendingLink = false);
    }
  }

  bool _isValidEmail(String s) {
    // Regex simple, pas RFC-strict — on veut juste catcher les typos évidents.
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
  }

  String _translateError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('rate limit')) {
      return 'Trop de tentatives. Attends une minute.';
    }
    if (lower.contains('invalid')) {
      return 'Email invalide.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: forestGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              _buildHeader(),
              const SizedBox(height: 56),
              if (_linkSent)
                _buildLinkSentBanner()
              else ...[
                _buildEmailField(),
                const SizedBox(height: 14),
                _buildMagicLinkButton(),
                const SizedBox(height: 16),
                Text(
                  "On t'envoie un lien magique pour te connecter — pas de mot de passe à retenir.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFFC4A572),
                    height: 1.5,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.karla(
                    color: const Color(0xFFFF8A80),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [goldLight, gold],
            ),
            boxShadow: [
              BoxShadow(
                color: goldLight.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.pets, size: 40, color: forestGreen),
        ),
        const SizedBox(height: 24),
        Text(
          'Spotted',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 44,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: surfaceBase,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Ton carnet naturaliste',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFC4A572),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    const accent = Color(0xFFC4A572);
    return Container(
      decoration: BoxDecoration(
        color: surfaceBase.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _sendMagicLink(),
        enabled: !_isSendingLink,
        style: GoogleFonts.karla(color: surfaceBase, fontSize: 15),
        cursorColor: gold,
        decoration: InputDecoration(
          hintText: 'ton@email.com',
          hintStyle: GoogleFonts.karla(
            color: accent.withValues(alpha: 0.6),
            fontSize: 15,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildMagicLinkButton() {
    return FilledButton(
      onPressed: _isSendingLink ? null : _sendMagicLink,
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: forestGreen,
        disabledBackgroundColor: gold.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isSendingLink
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: forestGreen,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "RECEVOIR MON LIEN",
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: forestGreen,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16, color: forestGreen),
              ],
            ),
    );
  }

  /// État post-tap "Recevoir un lien" — confirmation + instruction claire.
  /// L'user quitte l'app pour son mail, tap le lien → deep link revient
  /// ici, session créée, router redirige.
  Widget _buildLinkSentBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceBase.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gold.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: gold, size: 40),
          const SizedBox(height: 12),
          Text(
            'Vérifie tes emails',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: surfaceBase,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'On t\'a envoyé un lien de connexion à\n${_emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.karla(
              fontSize: 13,
              color: const Color(0xFFC4A572),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                setState(() => _linkSent = false),
            child: Text(
              'Renvoyer un lien',
              style: GoogleFonts.karla(
                fontSize: 12,
                color: gold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // Le redirect /login → / est géré par la garde de route (Phase 3.E).
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _translateError(e.message));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur inattendue');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _translateError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email non confirmé.';
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
              _buildField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _passwordController,
                label: 'Mot de passe',
                obscure: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFFC4A572),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
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
              const SizedBox(height: 32),
              _buildSubmitButton(),
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
          'Carnet de chasse naturaliste',
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    Widget? suffix,
    bool autofocus = false,
  }) {
    const accent = Color(0xFFC4A572);
    return Container(
      decoration: BoxDecoration(
        color: surfaceBase.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
              enabled: !_isLoading,
              style: GoogleFonts.karla(color: surfaceBase, fontSize: 15),
              cursorColor: gold,
              decoration: InputDecoration(
                labelText: label.toUpperCase(),
                labelStyle: GoogleFonts.karla(
                  color: accent,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isLoading ? null : _signIn,
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: forestGreen,
        disabledBackgroundColor: gold.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.karla(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: forestGreen,
              ),
            )
          : const Text('CONNEXION'),
    );
  }
}

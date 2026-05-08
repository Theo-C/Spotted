import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Connexion',
      icon: Icons.lock_outline,
      subtitle: 'Phase 3 : Auth Supabase (Léo / Marine).',
    );
  }
}

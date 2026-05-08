import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Profil',
      icon: Icons.person_outline,
      subtitle: 'Bientôt : niveau, stats, toggle observateur.',
    );
  }
}

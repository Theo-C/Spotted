import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Explorer',
      icon: Icons.explore_outlined,
      subtitle: "Bientôt : carte de l'Oise + drill-down catégories.",
    );
  }
}

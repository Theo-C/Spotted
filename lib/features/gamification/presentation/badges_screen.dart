import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import 'badges_section.dart';

/// Route /badges — affiche la grille complète des badges en page dédiée
/// (vs ancien DraggableScrollableSheet). Avantages : back natif système
/// + iOS swipe back, scroll naturel, deep-linkable, mieux pour 13+ badges.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBase,
      appBar: AppBar(
        title: Text(
          'Badges',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: BadgesSection(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/theme.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Carnet',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
      ),
      body: MapWidget(
        // Centre approximatif de l'Oise, zoom département.
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(2.82, 49.41)),
          zoom: 9.0,
        ),
        styleUri: MapboxStyles.OUTDOORS,
      ),
    );
  }
}

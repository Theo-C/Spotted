import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:native_exif/native_exif.dart';

/// Résultat d'une sélection de photo depuis la galerie, avec métadonnées
/// extraites de l'EXIF (si disponibles).
class PickedPhoto {
  const PickedPhoto({
    required this.file,
    this.takenAt,
    this.latitude,
    this.longitude,
    this.exif,
  });

  final File file;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;

  /// Métadonnées EXIF brutes (à stocker dans observations.photo_exif_data).
  final Map<String, dynamic>? exif;

  bool get hasGps => latitude != null && longitude != null;
}

class PhotoPickerService {
  PhotoPickerService(this._picker);

  final ImagePicker _picker;

  /// Ouvre la galerie photo, lit l'EXIF du fichier sélectionné.
  /// Renvoie null si l'utilisateur annule.
  Future<PickedPhoto?> pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final file = File(picked.path);
    return _readExif(file);
  }

  Future<PickedPhoto> _readExif(File file) async {
    DateTime? takenAt;
    double? lat;
    double? lng;
    Map<String, dynamic>? rawExif;
    try {
      final exif = await Exif.fromPath(file.path);
      final attrs = await exif.getAttributes();
      rawExif = attrs;
      if (attrs != null) {
        // Date
        final dateStr = attrs['DateTimeOriginal'] as String? ??
            attrs['DateTime'] as String?;
        if (dateStr != null) {
          takenAt = _parseExifDate(dateStr);
        }
        // GPS — native_exif renvoie déjà lat/lng en double signés (négatif si W/S).
        final latRaw = attrs['GPSLatitude'];
        final lngRaw = attrs['GPSLongitude'];
        if (latRaw is num && lngRaw is num) {
          lat = latRaw.toDouble();
          lng = lngRaw.toDouble();
        }
      }
      await exif.close();
    } catch (_) {
      // EXIF illisible ou photo sans métadonnées — on garde juste le fichier.
    }
    return PickedPhoto(
      file: file,
      takenAt: takenAt,
      latitude: lat,
      longitude: lng,
      exif: rawExif,
    );
  }

  /// Format EXIF "YYYY:MM:DD HH:mm:ss" → DateTime.
  DateTime? _parseExifDate(String raw) {
    try {
      final parts = raw.split(' ');
      if (parts.length != 2) return null;
      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');
      if (dateParts.length != 3 || timeParts.length != 3) return null;
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}

final photoPickerServiceProvider = Provider<PhotoPickerService>((ref) {
  return PhotoPickerService(ImagePicker());
});

import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_exif/native_exif.dart';
import 'package:permission_handler/permission_handler.dart';

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

/// Sélectionne une photo et lit son EXIF.
///
/// Utilise [FilePicker] (intent ACTION_OPEN_DOCUMENT) plutôt que [ImagePicker]
/// pour préserver les EXIF GPS sur Android 13+ — le nouveau Photo Picker
/// les strippe systématiquement.
class PhotoPickerService {
  /// Ouvre le file picker, renvoie null si l'utilisateur annule.
  /// On utilise FileType.custom pour forcer ACTION_OPEN_DOCUMENT — FileType.image
  /// peut basculer sur le Photo Picker selon les vendors Android.
  ///
  /// On demande ACCESS_MEDIA_LOCATION au runtime (Android 10+) AVANT le pick
  /// pour que les EXIF GPS ne soient pas redactés lors de la copie en cache.
  Future<PickedPhoto?> pickFromGallery() async {
    if (Platform.isAndroid) {
      final status = await Permission.accessMediaLocation.request();
      developer.log(
        'ACCESS_MEDIA_LOCATION runtime status: $status',
        name: 'photo_picker',
      );
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) return null;
    developer.log(
      'file_picker returned path: $path',
      name: 'photo_picker',
    );
    return _readExif(File(path));
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
      developer.log(
        'EXIF attrs (${attrs?.length ?? 0} keys): $attrs',
        name: 'photo_picker',
      );
      if (attrs != null) {
        // Date
        final dateStr = attrs['DateTimeOriginal'] as String? ??
            attrs['DateTime'] as String?;
        if (dateStr != null) {
          takenAt = _parseExifDate(dateStr);
        }
        // GPS — robuste : num signé, num + ref (N/S/E/W), ou string DMS "X,Y,Z"
        lat = _parseGpsCoordinate(
          raw: attrs['GPSLatitude'],
          ref: attrs['GPSLatitudeRef'] as String?,
          negativeRef: 'S',
        );
        lng = _parseGpsCoordinate(
          raw: attrs['GPSLongitude'],
          ref: attrs['GPSLongitudeRef'] as String?,
          negativeRef: 'W',
        );
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

  /// Extrait une coordonnée GPS depuis l'EXIF.
  /// Accepte 3 formats :
  ///   - num signé (29.5, -16.62) — déjà en degrés décimaux
  ///   - num positif + ref "N"/"S"/"E"/"W" (28.45 + "S" = -28.45)
  ///   - string DMS "29,30,15" (degrés, minutes, secondes)
  double? _parseGpsCoordinate({
    required Object? raw,
    required String? ref,
    required String negativeRef,
  }) {
    if (raw == null) return null;
    double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      if (raw.contains(',')) {
        final parts = raw.split(',');
        if (parts.length == 3) {
          final deg = double.tryParse(parts[0].trim());
          final min = double.tryParse(parts[1].trim());
          final sec = double.tryParse(parts[2].trim());
          if (deg != null && min != null && sec != null) {
            value = deg + min / 60 + sec / 3600;
          }
        }
      } else {
        value = double.tryParse(raw.trim());
      }
    }
    if (value == null) return null;
    // Ajuste le signe selon la référence (S/W = négatif).
    if (ref != null && ref.toUpperCase() == negativeRef) {
      value = -value.abs();
    }
    return value;
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
  return PhotoPickerService();
});

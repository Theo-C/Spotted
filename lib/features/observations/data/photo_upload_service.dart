import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/supabase_client_provider.dart';

/// Upload de photos d'observation vers le bucket Supabase Storage 'observations'.
class PhotoUploadService {
  PhotoUploadService(this._client);

  final SupabaseClient _client;

  /// Upload [file] dans le bucket 'observations' sous le chemin
  /// {observerUserId}/{timestamp}.{ext}. Renvoie l'URL publique.
  Future<String> uploadObservationPhoto({
    required File file,
    required String observerUserId,
  }) async {
    final ext = _extensionOf(file.path);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$observerUserId/$ts$ext';
    await _client.storage.from('observations').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
    return _client.storage.from('observations').getPublicUrl(path);
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '.jpg';
    return path.substring(dot).toLowerCase();
  }
}

final photoUploadServiceProvider = Provider<PhotoUploadService>((ref) {
  return PhotoUploadService(ref.watch(supabaseClientProvider));
});

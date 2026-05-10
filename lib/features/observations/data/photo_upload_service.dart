import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/supabase_client_provider.dart';

/// Upload de photos vers Supabase Storage. Deux buckets distincts :
///  - 'observations' : photo d'une obs précise (1 par obs).
///  - 'species'      : photo d'illustration d'une espèce du catalogue
///                     (1 par espèce, partagée entre les obs).
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

  /// Upload [file] dans le bucket 'species' sous le chemin
  /// {uploaderUserId}/{timestamp}.{ext}. Renvoie l'URL publique.
  /// Le path inclut le userId pour la traçabilité (qui a uploadé), mais
  /// la photo "appartient" logiquement à l'espèce — n'importe qui peut
  /// la remplacer via l'éditeur.
  Future<String> uploadSpeciesPhoto({
    required File file,
    required String uploaderUserId,
  }) async {
    final ext = _extensionOf(file.path);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$uploaderUserId/$ts$ext';
    await _client.storage.from('species').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false),
        );
    return _client.storage.from('species').getPublicUrl(path);
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

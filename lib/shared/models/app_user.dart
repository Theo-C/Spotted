import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// Profil utilisateur Spotted (extension de auth.users côté Supabase).
/// Nommé AppUser pour éviter la collision avec User de supabase_flutter.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String pseudo,
    required String colorAccent,
    required DateTime createdAt,
    @Default(false) bool isAdmin,
    @Default(false) bool profileCompleted,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}

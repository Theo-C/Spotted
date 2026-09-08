import 'package:intl/intl.dart';

/// Helpers de formatage de date centralisés — évite la duplication des
/// patterns `DateFormat(..., 'fr').format(...)` éparpillés dans les
/// features, et garantit la cohérence visuelle entre écrans similaires.
///
/// Deux styles selon le contexte :
///
///   - [DateFormatter.relative] pour les feeds "récent" (obs récentes,
///     activité) — plus vivant, contextuel (« il y a 2 h », « hier »).
///   - [DateFormatter.full] pour le détail d'une entité (fiche obs,
///     historique d'une espèce) — précis et non ambigu.
class DateFormatter {
  DateFormatter._();

  /// Format court, précis à la journée : « 3 sept. 2026 ».
  static String full(DateTime when) =>
      DateFormat('d MMM yyyy', 'fr').format(when);

  /// Format encore plus court sans année : « 3 sept. ». Pour les feeds où
  /// l'année n'apporte rien (obs de la semaine).
  static String shortNoYear(DateTime when) =>
      DateFormat('d MMM', 'fr').format(when);

  /// Format relatif humain — « à l'instant », « il y a 3 h », « hier »,
  /// « il y a 4 j ». Pour les feeds "activité récente". Bascule sur
  /// [shortNoYear] au-delà d'une semaine pour rester compact et lisible.
  static String relative(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.isNegative) return full(when); // date future rare — full pour être clair
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return shortNoYear(when);
  }
}

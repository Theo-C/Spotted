import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Rappel quotidien pour entretenir la série naturaliste.
/// Notification locale (pas FCM), programmée à 13:00 heure locale.
/// L'user opt-in via une dialog à la 1ère ouverture (cf. onboarding) et peut
/// activer/désactiver à tout moment dans le Profil.
class NotificationsService {
  static const _kEnabled = 'notifs_streak_enabled';
  static const _kPromptShown = 'notifs_opt_in_prompt_shown';
  static const _channelId = 'streak_reminder';
  static const _streakNotifId = 1001;

  /// Heure locale du rappel (13:00). Pause déjeuner / début d'après-midi :
  /// fenêtre où l'on est encore dispo pour aller dehors prendre une obs.
  /// En dur pour le MVP — pas de picker.
  static const _reminderHour = 13;

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Force la timezone locale à Europe/Paris. Sans ça, `tz.local` reste UTC
    // par défaut → "13:00 local" devient "13:00 UTC" → 14:00 en France l'hiver
    // (CET) ou 15:00 en été (CEST). Bug rapporté 2026-05-13 : user n'a rien
    // reçu à 13h pile parce que la notif fire en réalité à 14h/15h.
    // MVP France-only : hardcoded acceptable. Multi-TZ → utiliser
    // flutter_timezone pour détecter dynamiquement.
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(init);
    _initialized = true;
  }

  /// True si l'utilisateur a déjà vu la dialog d'opt-in (qu'il ait dit oui ou non).
  Future<bool> hasSeenOptInPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPromptShown) ?? false;
  }

  Future<void> markOptInPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPromptShown, true);
  }

  /// True si l'user a activé le rappel quotidien.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  /// Active le rappel : demande la permission OS, planifie la notif daily,
  /// puis persiste l'état. Retourne false si la permission a été refusée.
  Future<bool> enable() async {
    await _ensureInitialized();

    // Permission OS (Android 13+ : POST_NOTIFICATIONS ; iOS : prompt natif).
    final status = await Permission.notification.request();
    if (!status.isGranted) return false;

    // Sur Android 12+, SCHEDULE_EXACT_ALARM est une permission spéciale
    // que l'user doit accorder via les paramètres système (pas auto-granted).
    // On la demande poliment : si refusée, on fallback sur inexactAllowWhileIdle
    // qui marche sans permission spéciale mais peut être retardée en doze mode.
    await Permission.scheduleExactAlarm.request();

    await _scheduleDaily();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    return true;
  }

  /// Détermine si on peut utiliser exactAllowWhileIdle (heure pile garantie)
  /// ou si on doit retomber sur inexactAllowWhileIdle (peut être retardé).
  Future<AndroidScheduleMode> _bestScheduleMode() async {
    final s = await Permission.scheduleExactAlarm.status;
    return s.isGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Désactive le rappel : annule la notif planifiée + persiste l'état.
  Future<void> disable() async {
    await _ensureInitialized();
    await _plugin.cancel(_streakNotifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
  }

  /// (Re)planifie la notif daily à 13:00 locale. Appelé à la fois par enable()
  /// et par le boot de l'app si l'user avait déjà opt-in (pour rafraîchir la
  /// timezone et resync après éventuel reboot device).
  Future<void> _scheduleDaily() async {
    await _ensureInitialized();
    final tzNow = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      tzNow.year,
      tzNow.month,
      tzNow.day,
      _reminderHour,
    );
    if (!scheduled.isAfter(tzNow)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final mode = await _bestScheduleMode();
    await _plugin.zonedSchedule(
      _streakNotifId,
      "Ne perds pas ta série !",
      "Une obs aujourd'hui suffit pour garder ta flamme allumée 🔥",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Rappel série',
          channelDescription: 'Rappel quotidien pour entretenir la série',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Au boot : si l'user avait opt-in, re-planifie pour s'assurer que la
  /// notif est toujours là (Android peut clear les schedules après reboot).
  Future<void> reconcileOnBoot() async {
    if (await isEnabled()) {
      await _scheduleDaily();
    }
  }

}

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService();
});

/// État courant : enabled / disabled. Watch par l'UI Profil pour afficher
/// le switch dans le bon état.
final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(notificationsServiceProvider).isEnabled();
});

/// True tant que la dialog d'opt-in n'a pas été montrée à l'user (1ère fois).
final notificationsOptInPromptProvider = FutureProvider<bool>((ref) async {
  return !await ref
      .watch(notificationsServiceProvider)
      .hasSeenOptInPrompt();
});

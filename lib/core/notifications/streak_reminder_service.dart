import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// On-device "keep your streak alive" nudge (PRD section 10 — optional
/// v1.1, and section 3's "local notifications only, if included"
/// non-goal). No backend involved: a single local notification is
/// scheduled for this evening and cancelled the moment the user logs a
/// transaction, so it only ever fires when the day's streak is at risk.
///
/// A no-op everywhere the underlying plugin doesn't apply — this app's
/// web target exists only for local dev/testing, not the PRD's actual
/// Android/iOS platforms.
class StreakReminderService {
  StreakReminderService._();
  static final StreakReminderService instance = StreakReminderService._();

  static const _reminderId = 1001;
  static const _reminderHour = 20; // 8 PM local

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (kIsWeb || _initialized) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Platform couldn't report a timezone name — fall back to whatever
      // `timezone` defaults to; the reminder still fires, just possibly
      // not at exactly 8pm local.
    }
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  /// Prompts for the OS notification permission — only call this from an
  /// explicit user action (the Profile toggle), never at app startup.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _ensureInitialized();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Schedules tonight's reminder at 8pm local (tomorrow's if it's already
  /// past 8pm today). Safe to call repeatedly — each call replaces the
  /// previously scheduled one.
  Future<void> scheduleTonightReminder({required int currentStreak}) async {
    if (kIsWeb) return;
    await _ensureInitialized();

    final body = currentStreak > 0
        ? "You're on a $currentStreak-day streak — log something before it resets."
        : 'Log a transaction today to start a streak.';

    await _plugin.zonedSchedule(
      _reminderId,
      'Keep your streak alive',
      body,
      _next8pm(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminder',
          'Streak reminders',
          channelDescription:
              "A nudge if you haven't logged anything today yet",
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels today's pending reminder — call right after a transaction is
  /// logged, since the streak is already safe for today.
  Future<void> cancelToday() async {
    if (kIsWeb) return;
    await _plugin.cancel(_reminderId);
  }

  tz.TZDateTime _next8pm() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, _reminderHour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

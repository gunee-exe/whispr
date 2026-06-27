import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../models/reminder.dart';
import '../models/trigger_model.dart';

/// Section 4.1 — Notification Scheduling Service
///
/// Centralizes all flutter_local_notifications scheduling for Whispr.
/// - Single and recurring triggers
/// - Multiple triggers per Reminder
/// - Update / cancel on edit / delete
/// - Riverpod-exposed
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'whispr_reminders';
  static const String _channelName = 'Whispr Reminders';
  static const String _channelDesc = 'Smart reminders from Whispr';

  /// Must be called once at app startup, before scheduling anything.
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Use device local timezone. On real devices you can use flutter_native_timezone.
    final String localTz = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
      // Best-effort local tz resolution – fall back to UTC if unknown.
      final loc = tz.timeZoneDatabase.locations[localTz];
      if (loc != null) tz.setLocalLocation(loc);
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Android 13+ runtime permission
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // GoRouter deep-link handling is wired in the UI layer.
    // Payload format: reminderId|triggerId
    debugPrint('Whispr notification tapped: ${response.payload}');
  }

  /// Schedule all triggers for a reminder.
  /// Cancels existing notifications for this reminder first (safe for updates).
  Future<void> scheduleReminder(
    Reminder reminder, {
    bool soundEnabled = true,
    List<int> snoozeMinutes = const [5, 60],
  }) async {
    await init();
    await cancelAllForReminder(reminder);

    for (final trigger in reminder.triggers) {
      if (trigger.fired) continue;
      if (trigger.fireAt.isBefore(DateTime.now())) continue;
      await _scheduleTrigger(
        reminder: reminder,
        trigger: trigger,
        soundEnabled: soundEnabled,
        snoozeMinutes: snoozeMinutes,
      );
    }

    // Recurring expansion: if a RecurrenceModel exists, schedule the next
    // N materialized occurrences based on timesOfDay/daysOfWeek.
    // The AI normally materializes triggers, but this covers pure-recurring reminders.
    if (reminder.recurrence != null && reminder.triggers.isEmpty) {
      await _scheduleRecurrence(
        reminder,
        soundEnabled: soundEnabled,
        snoozeMinutes: snoozeMinutes,
      );
    }
  }

  Future<void> _scheduleTrigger({
    required Reminder reminder,
    required TriggerModel trigger,
    required bool soundEnabled,
    required List<int> snoozeMinutes,
  }) async {
    final tz.TZDateTime scheduled = tz.TZDateTime.from(
      trigger.fireAt,
      tz.local,
    );

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: soundEnabled,
      sound: soundEnabled ? const RawResourceAndroidNotificationSound('whispr_chime') : null,
      category: AndroidNotificationCategory.reminder,
      actions: [
        for (final m in snoozeMinutes)
          AndroidNotificationAction(
            'snooze_$m',
            'Snooze ${m}m',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        const AndroidNotificationAction(
          'mark_done',
          'Done',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundEnabled ? 'whispr_chime.caf' : null,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _plugin.zonedSchedule(
        trigger.localNotificationId,
        reminder.taskTitle,
        trigger.label.isNotEmpty ? trigger.label : 'Reminder',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '${reminder.reminderId}|${trigger.triggerId}',
      );
    } catch (e, st) {
      debugPrint('Whispr schedule failed for ${trigger.triggerId}: $e\n$st');
      rethrow;
    }
  }

  Future<void> _scheduleRecurrence(
    Reminder reminder, {
    required bool soundEnabled,
    required List<int> snoozeMinutes,
    int occurrences = 14,
  }) async {
    final r = reminder.recurrence!;
    if (r.timesOfDay.isEmpty) return;

    final now = DateTime.now();
    int scheduled = 0;
    DateTime cursor = now;

    while (scheduled < occurrences) {
      for (final tod in r.timesOfDay) {
        final parts = tod.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]) ?? 9;
        final m = int.tryParse(parts[1]) ?? 0;
        final candidate = DateTime(cursor.year, cursor.month, cursor.day, h, m);

        if (candidate.isBefore(now)) continue;
        if (r.endDate != null && candidate.isAfter(r.endDate!)) continue;

        final weekday = candidate.weekday % 7; // 0=Sun … 6=Sat to match model
        if (r.type == 'custom_days' || r.type == 'weekly') {
          if (r.daysOfWeek != null &&
              r.daysOfWeek!.isNotEmpty &&
              !r.daysOfWeek!.contains(weekday)) {
            continue;
          }
        }

        final fakeTrigger = TriggerModel(
          triggerId: 'rec_${reminder.reminderId}_$scheduled',
          fireAt: candidate,
          label: tod,
          kind: 'fixed_time',
          localNotificationId: _deriveNotificationId(
            reminder.reminderId,
            'rec_$scheduled',
          ),
          liveActivityWindowMinutes: 30,
        );

        await _scheduleTrigger(
          reminder: reminder,
          trigger: fakeTrigger,
          soundEnabled: soundEnabled,
          snoozeMinutes: snoozeMinutes,
        );
        scheduled++;
        if (scheduled >= occurrences) break;
      }
      cursor = cursor.add(const Duration(days: 1));
      // safety guard – don't schedule > 60 days out
      if (cursor.difference(now).inDays > 60) break;
    }
  }

  Future<void> cancelTrigger(TriggerModel trigger) async {
    try {
      await _plugin.cancel(trigger.localNotificationId);
    } catch (e) {
      debugPrint('Whispr cancel failed: $e');
    }
  }

  Future<void> cancelAllForReminder(Reminder reminder) async {
    for (final t in reminder.triggers) {
      await cancelTrigger(t);
    }
  }

  /// Immediate snooze helper – cancels the firing notification and schedules a one-off.
  Future<int> snoozeOnce({
    required Reminder reminder,
    required TriggerModel originalTrigger,
    required Duration snooze,
    bool soundEnabled = true,
  }) async {
    await cancelTrigger(originalTrigger);
    final snoozeAt = DateTime.now().add(snooze);
    final snoozeTrigger = TriggerModel(
      triggerId: '${originalTrigger.triggerId}_snooze_${snooze.inMinutes}',
      fireAt: snoozeAt,
      label: 'Snoozed ${snooze.inMinutes}m',
      kind: 'snooze',
      localNotificationId: _deriveNotificationId(
        reminder.reminderId,
        'snooze_${DateTime.now().microsecondsSinceEpoch}',
      ),
      liveActivityWindowMinutes: 5,
    );

    await _scheduleTrigger(
      reminder: reminder,
      trigger: snoozeTrigger,
      soundEnabled: soundEnabled,
      snoozeMinutes: const [5, 60],
    );
    return snoozeTrigger.localNotificationId;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  /// Stable, positive 31-bit int ID for flutter_local_notifications.
  static int _deriveNotificationId(String reminderId, String triggerId) {
    return (reminderId.hashCode ^ triggerId.hashCode) & 0x7fffffff;
  }

  /// Public helper – used by LocalReminderService when assigning IDs.
  static int allocateNotificationId(String reminderId, String triggerId) =>
      _deriveNotificationId(reminderId, triggerId);
}

/// Background tap handler – must be top-level.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // No-op – full handling happens in foreground via go_router.
}

// --- Riverpod ---

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationInitProvider = FutureProvider<void>((ref) async {
  final svc = ref.read(notificationServiceProvider);
  await svc.init();
});

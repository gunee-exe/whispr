import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../models/trigger_model.dart';
import 'notification_service.dart';
import 'live_activity_service.dart';

const _uuid = Uuid();
const String remindersBoxName = 'reminders';

/// Section 7.2a — App-Open Local Routines
///
/// Three housekeeping routines that run on every app open / resume.
/// They replace what would have been scheduled Cloud Functions in an older
/// architecture, since all data now lives on-device in Hive.
class TriggerService {
  final NotificationService _notifications;
  final LiveActivityService _liveActivity;

  TriggerService({
    NotificationService? notifications,
    LiveActivityService? liveActivity,
  })  : _notifications = notifications ?? NotificationService(),
        _liveActivity = liveActivity ?? LiveActivityService();

  Box<Reminder> get _remindersBox => Hive.box<Reminder>(remindersBoxName);

  // ---------------------------------------------------------------------------
  // 1. generateNextTriggers
  // ---------------------------------------------------------------------------

  /// For every recurring reminder whose current triggers have all fired,
  /// computes and appends the next occurrence's trigger(s) per the recurrence
  /// map, then re-schedules local notifications.
  ///
  /// Called on app open/resume and once daily if the app stays foregrounded.
  Future<void> generateNextTriggers() async {
    final now = DateTime.now();
    for (final reminder in _remindersBox.values) {
      if (reminder.status != 'active') continue;
      if (reminder.recurrence == null) continue;

      // Check whether all existing triggers have fired or are past.
      final allFired = reminder.triggers.every(
        (t) => t.fired || t.fireAt.isBefore(now),
      );
      if (!allFired) continue;

      // Generate the next N occurrences based on the recurrence model.
      final nextTriggers = _computeNextOccurrences(reminder, now);
      if (nextTriggers.isEmpty) {
        // No more occurrences — recurrence has ended.
        reminder.status = 'completed';
        await reminder.save();
        continue;
      }

      // Assign stable localNotificationIds for the new triggers.
      int counter = reminder.triggers.length;
      for (final t in nextTriggers) {
        t.localNotificationId = NotificationService.allocateNotificationId(
          reminder.reminderId,
          t.triggerId,
        );
        counter++;
      }

      reminder.triggers.addAll(nextTriggers);
      reminder.updatedAt = now;
      await reminder.save();

      // Re-schedule notifications for the new triggers.
      try {
        await _notifications.scheduleReminder(reminder);
      } catch (e, st) {
        debugPrint('TriggerService.generateNextTriggers schedule error: $e\n$st');
      }
    }
  }

  /// Computes up to [count] future trigger DateTimes from a reminder's
  /// recurrence model, starting from [after].
  List<TriggerModel> _computeNextOccurrences(
    Reminder reminder,
    DateTime after, {
    int count = 14,
  }) {
    final r = reminder.recurrence!;
    if (r.timesOfDay.isEmpty) return [];

    final List<TriggerModel> results = [];
    var cursor = after;
    var iterations = 0;

    while (results.length < count && iterations < 365) {
      iterations++;
      for (final tod in r.timesOfDay) {
        final parts = tod.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]) ?? 9;
        final m = int.tryParse(parts[1]) ?? 0;
        final candidate = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
          h,
          m,
        );

        if (!candidate.isAfter(after)) continue;
        if (r.endDate != null && candidate.isAfter(r.endDate!)) {
          return results; // Past end date — stop generating.
        }

        // Filter by days-of-week if applicable.
        if (r.type == 'weekly' || r.type == 'custom_days') {
          // dart weekday: 1=Mon…7=Sun; model: 0=Sun…6=Sat
          final dayIndex = candidate.weekday % 7;
          if (r.daysOfWeek != null &&
              r.daysOfWeek!.isNotEmpty &&
              !r.daysOfWeek!.contains(dayIndex)) {
            continue;
          }
        }

        final triggerId = '${_uuid.v4()}_rec';
        results.add(
          TriggerModel(
            triggerId: triggerId,
            fireAt: candidate,
            label: tod,
            kind: 'fixed_time',
            localNotificationId: 0, // Assigned by caller.
            liveActivityWindowMinutes: 30,
          ),
        );

        if (results.length >= count) return results;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // 2. cleanupExpiredClarifications
  // ---------------------------------------------------------------------------

  /// Deletes pendingClarifications entries older than 24 hours.
  /// Called on every app open — kept in LocalReminderService but surfaced
  /// here too so callers have one import to coordinate all three routines.
  Future<void> cleanupExpiredClarifications() async {
    // Delegated to LocalReminderService where the clarifications box lives.
    // This stub exists so the caller's app-open routine can be a single call
    // to TriggerService without needing a separate LocalReminderService import.
    //
    // In practice the app's lifecycle handler calls both:
    //   await localReminderService.cleanupExpiredClarifications();
    //   await triggerService.generateNextTriggers();
    //   await triggerService.checkUpcomingTriggers();
    debugPrint(
      'TriggerService.cleanupExpiredClarifications: delegate to LocalReminderService',
    );
  }

  // ---------------------------------------------------------------------------
  // 3. checkUpcomingTriggers
  // ---------------------------------------------------------------------------

  /// Scans upcoming triggers and manages Live Activities / Android ongoing
  /// notifications. Should run on app open/resume and via an in-app periodic
  /// timer (every ~30 seconds) while the app is foregrounded.
  ///
  /// Section 7.3 / 7.4:
  ///  - Triggers entering their liveActivityWindowMinutes → start Live Activity.
  ///  - 2+ triggers within 2 hours → merge into one "N things due soon" activity.
  ///  - Fires and clears → end the Live Activity.
  Future<void> checkUpcomingTriggers() async {
    final now = DateTime.now();
    final twoHoursOut = now.add(const Duration(hours: 2));

    // Collect all active, unfired triggers entering their live-activity window.
    final List<_UpcomingTrigger> entering = [];

    for (final reminder in _remindersBox.values) {
      if (reminder.status != 'active') continue;
      for (final trigger in reminder.triggers) {
        if (trigger.fired) continue;
        if (trigger.fireAt.isBefore(now)) continue;
        if (trigger.fireAt.isAfter(twoHoursOut)) {
          // Check if within the specific liveActivityWindowMinutes.
          final windowStart = trigger.fireAt.subtract(
            Duration(minutes: trigger.liveActivityWindowMinutes),
          );
          if (now.isBefore(windowStart)) continue;
        }
        entering.add(_UpcomingTrigger(reminder: reminder, trigger: trigger));
      }
    }

    if (entering.isEmpty) {
      // Nothing upcoming — ensure any stale Live Activity is ended.
      await _liveActivity.endAllActivities();
      return;
    }

    // Section 7.4 — merge if 2+ triggers within 2 hours.
    if (entering.length >= 2) {
      final nearest = entering.first;
      await _liveActivity.startOrUpdateMergedActivity(
        count: entering.length,
        nearestTitle: nearest.reminder.taskTitle,
        nearestFireAt: nearest.trigger.fireAt,
        activityId: 'merged_${entering.map((e) => e.trigger.triggerId).join('_')}',
      );
    } else {
      // Single trigger — start a dedicated Live Activity.
      final item = entering.first;
      await _liveActivity.startOrUpdateSingleActivity(
        reminderId: item.reminder.reminderId,
        triggerId: item.trigger.triggerId,
        title: item.reminder.taskTitle,
        fireAt: item.trigger.fireAt,
        label: item.trigger.label,
      );
    }
  }
}

/// Internal data class bundling a trigger with its parent reminder.
class _UpcomingTrigger {
  final Reminder reminder;
  final TriggerModel trigger;
  _UpcomingTrigger({required this.reminder, required this.trigger});
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final triggerServiceProvider = Provider<TriggerService>((ref) {
  return TriggerService();
});

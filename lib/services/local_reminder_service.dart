import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../models/pending_clarification.dart';
import '../models/settings.dart';
import '../features/home/confirmation_card_models.dart';
import 'notification_service.dart';

const _uuid = Uuid();

const String remindersBoxName = 'reminders';
const String pendingClarificationsBoxName = 'pendingClarifications';
const String settingsBoxName = 'settings';

/// Section 5.2 — Enhanced LocalReminderService
///
/// Drop-in replacement for the Section 1-3 version.
/// - Same public API / Provider signature (zero-arg constructor)
/// - Adds notification scheduling on save/update/delete
/// - Adds updateReminder / completeReminder / snoozeReminder helpers
class LocalReminderService {
  LocalReminderService({NotificationService? notifications})
    : _notifications = notifications ?? NotificationService();

  final NotificationService _notifications;

  Box<Reminder> get _remindersBox => Hive.box<Reminder>(remindersBoxName);
  Box<PendingClarification> get _clarificationsBox =>
      Hive.box<PendingClarification>(pendingClarificationsBoxName);
  Box<Settings> get _settingsBox => Hive.box<Settings>(settingsBoxName);

  Settings get _settings =>
      _settingsBox.isNotEmpty ? _settingsBox.values.first : Settings();

  /// Save a confirmed AI "ready" card as a Reminder.
  /// Assigns stable localNotificationIds and schedules notifications.
  Future<Reminder> saveReminderFromCard(ConfirmationCardData card) async {
    if (card.cardType != ConfirmationCardType.ready) {
      throw ArgumentError(
        'saveReminderFromCard expects ready, got ${card.cardType}',
      );
    }

    final now = DateTime.now();
    final reminderId = _uuid.v4();

    // Assign stable localNotificationIds — required for cancel/reschedule.
    final triggers = (card.triggers ?? []).map((t) {
      if (t.localNotificationId == 0) {
        t.localNotificationId = NotificationService.allocateNotificationId(
          reminderId,
          t.triggerId,
        );
      }
      if (t.liveActivityWindowMinutes == 30) {
        t.liveActivityWindowMinutes = _settings.defaultCountdownWindowMinutes;
      }
      return t;
    }).toList();

    final reminder = Reminder(
      reminderId: reminderId,
      taskTitle: card.taskTitle ?? 'Untitled reminder',
      originalInputText: card.inputMethod == 'voice'
          ? '[voice]'
          : card.originalInputText,
      inputMethod: card.inputMethod,
      detectedLanguage: 'mixed',
      dueAt: card.dueAt,
      triggers: triggers,
      recurrence: card.recurrence,
      createdAt: now,
      updatedAt: now,
      assumptionsMade: card.assumptionsMade,
    );

    await _remindersBox.put(reminder.reminderId, reminder);

    // Section 4/5 integration: schedule notifications immediately.
    try {
      await _notifications.scheduleReminder(
        reminder,
        soundEnabled: _settings.notificationSoundEnabled,
        snoozeMinutes: _settings.snoozeOptions,
      );
    } catch (e, st) {
      debugPrint('Whispr notification scheduling failed: $e\n$st');
      // Reminder is still saved — don't fail the whole save.
    }

    return reminder;
  }

  /// Update an existing reminder and re-schedule its notifications.
  Future<void> updateReminder(Reminder reminder) async {
    reminder.updatedAt = DateTime.now();
    reminder.lastEditedVia = 'manual_edit';
    await _remindersBox.put(reminder.reminderId, reminder);

    try {
      await _notifications.scheduleReminder(
        reminder,
        soundEnabled: _settings.notificationSoundEnabled,
        snoozeMinutes: _settings.snoozeOptions,
      );
    } catch (e, st) {
      debugPrint('Whispr re-schedule failed: $e\n$st');
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    final reminder = _remindersBox.get(reminderId);
    if (reminder != null) {
      await _notifications.cancelAllForReminder(reminder);
    }
    await _remindersBox.delete(reminderId);
  }

  Future<void> completeReminder(String reminderId) async {
    final r = _remindersBox.get(reminderId);
    if (r == null) return;
    r.status = 'completed';
    r.updatedAt = DateTime.now();
    await r.save();
    await _notifications.cancelAllForReminder(r);
  }

  Reminder? getReminder(String id) => _remindersBox.get(id);

  List<Reminder> getAllActiveReminders() {
    return _remindersBox.values.where((r) => r.status == 'active').toList()
      ..sort(
        (a, b) => (a.nextTriggerAt ?? a.dueAt ?? DateTime(9999)).compareTo(
          b.nextTriggerAt ?? b.dueAt ?? DateTime(9999),
        ),
      );
  }

  Stream<List<Reminder>> watchAllActiveReminders() {
    return _remindersBox.watch().map((_) => getAllActiveReminders());
  }

  /// Snooze a specific trigger.
  Future<void> snoozeReminder(
    String reminderId,
    String triggerId,
    Duration snooze,
  ) async {
    final reminder = _remindersBox.get(reminderId);
    if (reminder == null) throw StateError('Reminder not found');
    final trigger = reminder.triggers.firstWhere(
      (t) => t.triggerId == triggerId,
      orElse: () => throw StateError('Trigger not found'),
    );

    await _notifications.snoozeOnce(
      reminder: reminder,
      originalTrigger: trigger,
      snooze: snooze,
      soundEnabled: _settings.notificationSoundEnabled,
    );
  }

  // --- Pending clarification persistence ---
  Future<void> saveClarification(PendingClarification pc) =>
      _clarificationsBox.put(pc.clarificationId, pc);

  Future<void> cleanupExpiredClarifications() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final expired = _clarificationsBox.values
        .where((c) => c.createdAt.isBefore(cutoff))
        .toList();
    for (final c in expired) {
      await c.delete();
    }
  }

  /// Re-schedule all active reminders — called from Settings after changing sound/snooze prefs.
  Future<void> rescheduleAllActive() async {
    for (final r in getAllActiveReminders()) {
      await _notifications.scheduleReminder(
        r,
        soundEnabled: _settings.notificationSoundEnabled,
        snoozeMinutes: _settings.snoozeOptions,
      );
    }
  }
}

// Keep the exact same Provider signature as Sections 1-3
final localReminderServiceProvider = Provider<LocalReminderService>((ref) {
  return LocalReminderService();
});

final remindersListProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(localReminderServiceProvider).watchAllActiveReminders();
});

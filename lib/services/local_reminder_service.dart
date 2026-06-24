import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder.dart';
import '../models/pending_clarification.dart';
import '../main.dart' show remindersBoxName, pendingClarificationsBoxName;
import '../features/home/confirmation_card_models.dart';

const _uuid = Uuid();

/// All local reads/writes for reminders and clarifications — Section 5 and
/// Section 7.2a of the implementation plan. This is the app's only
/// "backend" for data; nothing here talks to a server.
class LocalReminderService {
  Box<Reminder> get _remindersBox => Hive.box<Reminder>(remindersBoxName);
  Box<PendingClarification> get _clarificationsBox =>
      Hive.box<PendingClarification>(pendingClarificationsBoxName);

  /// Saves a confirmed "ready" card as a real Reminder. Assigns a stable
  /// localNotificationId to each trigger (used later by NotificationService
  /// in Session 4 — generated now so it never changes once scheduled).
  Future<Reminder> saveReminderFromCard(ConfirmationCardData card) async {
    if (card.cardType != ConfirmationCardType.ready) {
      throw ArgumentError(
        'saveReminderFromCard expects a "ready" card; got ${card.cardType}. '
        'Resolve multi-task/clarification cards to a ready card first.',
      );
    }

    final now = DateTime.now();
    final triggers = (card.triggers ?? []).map((t) {
      t.localNotificationId = now.microsecondsSinceEpoch.remainder(1 << 31) +
          t.hashCode.remainder(10000);
      return t;
    }).toList();

    final reminder = Reminder(
      reminderId: _uuid.v4(),
      taskTitle: card.taskTitle ?? 'Untitled reminder',
      originalInputText:
          card.inputMethod == 'voice' ? '[voice]' : card.originalInputText,
      inputMethod: card.inputMethod,
      detectedLanguage: 'mixed', // refined once language detection is surfaced from the AI response
      dueAt: card.dueAt,
      triggers: triggers,
      recurrence: card.recurrence,
      createdAt: now,
      updatedAt: now,
      assumptionsMade: card.assumptionsMade,
    );

    await _remindersBox.put(reminder.reminderId, reminder);

    // Notification scheduling (flutter_local_notifications) is wired up in
    // Session 4 — intentionally not called here yet. The reminder is fully
    // saved and correct in storage regardless.

    return reminder;
  }

  Future<void> deleteReminder(String reminderId) async {
    await _remindersBox.delete(reminderId);
  }

  List<Reminder> getAllActiveReminders() {
    return _remindersBox.values.where((r) => r.status == 'active').toList()
      ..sort((a, b) => (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)));
  }

  Stream<List<Reminder>> watchAllActiveReminders() {
    return _remindersBox.watch().map((_) => getAllActiveReminders());
  }

  // --- Pending clarification persistence (Section 5.2) ---

  Future<PendingClarification> savePendingClarification({
    String? existingId,
    required String originalInputText,
    required List<Map<String, String>> conversationTurns,
    required Map<String, dynamic> partialParse,
  }) async {
    final id = existingId ?? _uuid.v4();
    final entry = PendingClarification(
      clarificationId: id,
      originalInputText: originalInputText,
      conversationTurns: conversationTurns,
      partialParse: partialParse,
      createdAt: DateTime.now(),
    );
    await _clarificationsBox.put(id, entry);
    return entry;
  }

  Future<void> deletePendingClarification(String clarificationId) async {
    await _clarificationsBox.delete(clarificationId);
  }

  /// App-open routine (Section 7.2a) — deletes clarification entries older
  /// than 24 hours that were never resolved. Call once from main.dart or
  /// the home screen's initState.
  Future<void> cleanupExpiredClarifications() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final expiredKeys = _clarificationsBox.keys.where((key) {
      final entry = _clarificationsBox.get(key);
      return entry != null && entry.createdAt.isBefore(cutoff);
    }).toList();
    for (final key in expiredKeys) {
      await _clarificationsBox.delete(key);
    }
  }
}

final localReminderServiceProvider = Provider<LocalReminderService>((ref) {
  return LocalReminderService();
});

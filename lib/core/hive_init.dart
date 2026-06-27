import 'package:hive_flutter/hive_flutter.dart';

import '../models/reminder.dart';
import '../models/trigger_model.dart';
import '../models/recurrence_model.dart';
import '../models/pending_clarification.dart';
import '../models/settings.dart';

const String remindersBoxName = 'reminders';
const String pendingClarificationsBoxName = 'pendingClarifications';
const String settingsBoxName = 'settings';

/// Section 5.1 — Hive Setup & Initialization
///
/// Call once at app startup before runApp().
/// All adapters are already registered in Person 1's main.dart; this
/// file consolidates that setup and adds the new Settings fields
/// (hapticsEnabled, defaultCountdownWindowMinutes) via a safe migration.
///
/// If upgrading from the Section 1-3 Settings model (3 fields),
/// Hive will read missing fields as null and the SettingsAdapter defaults
/// will fill them in (see settings.g.dart).
Future<void> initWhisprHive() async {
  await Hive.initFlutter();

  // Register adapters only once — safe to call repeatedly in tests.
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ReminderAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TriggerModelAdapter());
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(RecurrenceModelAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(PendingClarificationAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(SettingsAdapter());

  await Hive.openBox<Reminder>(remindersBoxName);
  await Hive.openBox<PendingClarification>(pendingClarificationsBoxName);
  final settingsBox = await Hive.openBox<Settings>(settingsBoxName);

  // Seed default settings on first launch.
  if (settingsBox.isEmpty) {
    await settingsBox.add(Settings());
  }
}

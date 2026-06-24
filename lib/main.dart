import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/router.dart';
import 'models/reminder.dart';
import 'models/trigger_model.dart';
import 'models/recurrence_model.dart';
import 'models/pending_clarification.dart';
import 'models/settings.dart';

const String remindersBoxName = 'reminders';
const String pendingClarificationsBoxName = 'pendingClarifications';
const String settingsBoxName = 'settings';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive setup — see Section 5 of the implementation plan.
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderAdapter());
  Hive.registerAdapter(TriggerModelAdapter());
  Hive.registerAdapter(RecurrenceModelAdapter());
  Hive.registerAdapter(PendingClarificationAdapter());
  Hive.registerAdapter(SettingsAdapter());

  await Hive.openBox<Reminder>(remindersBoxName);
  await Hive.openBox<PendingClarification>(pendingClarificationsBoxName);
  final settingsBox = await Hive.openBox<Settings>(settingsBoxName);

  // Seed default settings on first launch.
  if (settingsBox.isEmpty) {
    await settingsBox.add(Settings());
  }

  // No Firebase init needed — the AI proxy now runs on Cloudflare Workers
  // (cloudflare_worker_service.dart), not Firebase Cloud Functions, and
  // this app has no Auth/Firestore/Messaging usage at all (Section 4 of
  // the implementation plan). firebase_options.dart and the functions/
  // folder are left in the project only as reference/fallback in case you
  // ever want to switch hosting again — neither is required to run.

  runApp(const ProviderScope(child: WhisprApp()));
}

class WhisprApp extends StatelessWidget {
  const WhisprApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Whispr',
      theme: buildWhisprTheme(),
      routerConfig: whisprRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

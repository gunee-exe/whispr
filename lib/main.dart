import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/router.dart';
import 'models/reminder.dart';
import 'models/trigger_model.dart';
import 'models/recurrence_model.dart';
import 'models/pending_clarification.dart';
import 'models/settings.dart';
import 'firebase_options.dart';

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

  // Firebase init — needed only to call the single callAI Cloud Function
  // (Session 2). No Auth, no Firestore, no Messaging.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

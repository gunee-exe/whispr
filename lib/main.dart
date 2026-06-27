import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/router.dart';
import 'core/hive_init.dart';
import 'features/home/app_lifecycle_observer.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive: register all adapters and open all boxes.
  await initWhisprHive();

  // flutter_local_notifications: set up channels and request permissions.
  await NotificationService().init();

  runApp(const ProviderScope(child: WhisprApp()));
}

class WhisprApp extends StatelessWidget {
  const WhisprApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleObserver(
      // AppLifecycleObserver runs the three app-open routines
      // (cleanupExpiredClarifications, generateNextTriggers,
      //  checkUpcomingTriggers) on every launch and resume.
      child: MaterialApp.router(
        title: 'Whispr',
        theme: buildWhisprTheme(),
        routerConfig: whisprRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

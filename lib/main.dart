import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/router.dart';
import 'core/hive_init.dart';
import 'features/home/app_lifecycle_observer.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // Catches any error that would otherwise silently fail an async
  // callback (e.g. inside a StateNotifier method, a Hive stream's .map(),
  // or a Future started from a button's onPressed) and prints it clearly
  // instead of letting the screen go blank with no explanation. This is
  // the single biggest fix in this round — every "white screen" bug
  // reported was an uncaught exception with nowhere to go.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catches errors thrown during widget build/layout/paint — these
    // normally show Flutter's red error screen in debug mode, but
    // routing this through the same logging path keeps console output
    // consistent regardless of where an error originates.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    // Hive: register all adapters and open all boxes.
    await initWhisprHive();

    // flutter_local_notifications: set up channels and request permissions.
    await NotificationService().init();

    runApp(const ProviderScope(child: WhisprApp()));
  }, (error, stack) {
    debugPrint('UNCAUGHT ASYNC ERROR: $error');
    debugPrint('$stack');
  });
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

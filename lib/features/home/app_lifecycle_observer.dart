import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/trigger_service.dart';
import '../../services/local_reminder_service.dart';

/// Section 7.2a — App-open routine coordinator.
///
/// Wrap the top-level widget with [AppLifecycleObserver] so the three
/// housekeeping routines run on every app open/resume:
///   1. cleanupExpiredClarifications
///   2. generateNextTriggers
///   3. checkUpcomingTriggers
///
/// A periodic in-app timer also calls checkUpcomingTriggers every 30 seconds
/// while the app is foregrounded, as specified in Section 7.2a.
///
/// Usage in main.dart:
///   runApp(ProviderScope(child: AppLifecycleObserver(child: WhisprApp())));
class AppLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run immediately on first launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAppOpenRoutines());
    // Periodic check every 30 seconds while foregrounded.
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkUpcoming(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runAppOpenRoutines();
    }
  }

  Future<void> _runAppOpenRoutines() async {
    // 1. Cleanup stale clarifications.
    await ref
        .read(localReminderServiceProvider)
        .cleanupExpiredClarifications();
    // 2. Generate next triggers for recurring reminders.
    await ref.read(triggerServiceProvider).generateNextTriggers();
    // 3. Start/update any pending Live Activities.
    await ref.read(triggerServiceProvider).checkUpcomingTriggers();
  }

  Future<void> _checkUpcoming() async {
    await ref.read(triggerServiceProvider).checkUpcomingTriggers();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

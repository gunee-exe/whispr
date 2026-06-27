import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/Reminders/remindert_list_screen.dart';
import '../features/Reminders/reminder_detail_screen.dart';

/// All routes for Whispr. No auth-gating — renders directly into HomeScreen.
/// Matches the structure in Section 10 of the implementation plan.
final whisprRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/reminders',
      builder: (context, state) => const ReminderListScreen(),
    ),
    GoRoute(
      path: '/reminders/:id',
      builder: (context, state) => ReminderDetailScreen(
        reminderId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

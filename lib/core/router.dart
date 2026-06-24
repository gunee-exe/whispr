import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';

/// No auth-gated routes — the app renders directly into Home on launch.
/// List/Calendar, Reminder Detail, and Settings routes are added in
/// Session 4+; only Home exists through Session 3.
final whisprRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);

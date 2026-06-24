import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../services/local_reminder_service.dart';
import 'spark_bar.dart';
import 'spark_bar_provider.dart';
import 'confirmation_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // App-open routine — Section 7.2a. Cheap, safe to run every launch.
    ref.read(localReminderServiceProvider).cleanupExpiredClarifications();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sparkBarStateProvider);

    return Scaffold(
      backgroundColor: WhisprColors.morningPaper,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text('Whispr', style: WhisprText.display(size: 28, color: WhisprColors.spokenViolet)),
            const SizedBox(height: 6),
            Text(
              "Just say it. We'll handle the rest.",
              style: WhisprText.body(size: 14, color: WhisprColors.mutedInk).copyWith(fontStyle: FontStyle.italic),
            ),
            const Spacer(),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  state.errorMessage!,
                  style: WhisprText.body(size: 13, color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            if (state.cardData != null) ConfirmationCard(data: state.cardData!),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const SparkBar(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

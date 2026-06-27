import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import 'spark_bar.dart';
import 'spark_bar_provider.dart';
import 'confirmation_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sparkBarStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Whispr', style: WhisprText.display(size: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_rounded),
            onPressed: () => context.push('/reminders'),
            tooltip: 'All reminders',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content area — empty for now, reminders list goes here later
          const SizedBox.expand(),

          // Confirmation card — slides up when AI returns a result
          if (state.cardData != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: ConfirmationCard(
                data: state.cardData!,
                onConfirm: (finalData) {
                  return ref
                      .read(sparkBarStateProvider.notifier)
                      .confirmCard(finalData);
                },
                onDismiss: () {
                  ref.read(sparkBarStateProvider.notifier).dismissCard();
                },
              ),
            ),

          // Error snackbar trigger
          if (state.errorMessage != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: WhisprText.body(size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),

          // Spark Bar — pinned to bottom center
          const Positioned(left: 24, right: 24, bottom: 24, child: SparkBar()),
        ],
      ),
    );
  }
}

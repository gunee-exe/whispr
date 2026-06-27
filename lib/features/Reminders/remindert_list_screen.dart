import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/reminder.dart';
import '../../services/local_reminder_service.dart';

/// Section 4.2 — List/Calendar Route & UI
class ReminderListScreen extends ConsumerWidget {
  const ReminderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Nothing yet',
                      style: WhisprText.display(
                        size: 28,
                        color: WhisprColors.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type or speak a reminder on the home screen.',
                      style: WhisprText.body(color: WhisprColors.mutedInk),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Go to Spark Bar'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: reminders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ReminderCard(reminder: reminders[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.mic_rounded),
        label: const Text('New'),
        backgroundColor: WhisprColors.sparkCyan,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextAt = reminder.nextTriggerAt ?? reminder.dueAt;
    final dateStr = nextAt != null
        ? DateFormat('EEE, MMM d • h:mm a').format(nextAt)
        : 'No time set';
    final isDueSoon =
        nextAt != null &&
        nextAt.difference(DateTime.now()).inMinutes <= 60 &&
        nextAt.isAfter(DateTime.now());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/reminders/${reminder.reminderId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDueSoon
                      ? WhisprColors.emberAmber.withValues(alpha: 0.25)
                      : WhisprColors.calmMint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  reminder.recurrence != null
                      ? Icons.repeat_rounded
                      : Icons.alarm_rounded,
                  color: WhisprColors.plumInk,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.taskTitle,
                      style: WhisprText.body(size: 16, weight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: WhisprText.body(
                        size: 13,
                        color: WhisprColors.mutedInk,
                      ),
                    ),
                    if (reminder.triggers.length > 1)
                      Text(
                        '${reminder.triggers.length} triggers',
                        style: WhisprText.body(
                          size: 12,
                          color: WhisprColors.spokenViolet,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  final svc = ref.read(localReminderServiceProvider);
                  final trigger = reminder.triggers
                      .where((t) => !t.fired)
                      .toList();
                  trigger.sort((a, b) => a.fireAt.compareTo(b.fireAt));
                  if (trigger.isEmpty) return;
                  final nextTrigger = trigger.first;

                  try {
                    if (v == 'snooze_5') {
                      await svc.snoozeReminder(
                        reminder.reminderId,
                        nextTrigger.triggerId,
                        const Duration(minutes: 5),
                      );
                    } else if (v == 'snooze_60') {
                      await svc.snoozeReminder(
                        reminder.reminderId,
                        nextTrigger.triggerId,
                        const Duration(hours: 1),
                      );
                    } else if (v == 'done') {
                      await svc.completeReminder(reminder.reminderId);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            v == 'done' ? 'Marked done' : 'Snoozed',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'snooze_5', child: Text('Snooze 5 min')),
                  PopupMenuItem(value: 'snooze_60', child: Text('Snooze 1 hr')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'done', child: Text('Mark done')),
                ],
                icon: const Icon(Icons.more_vert, color: WhisprColors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

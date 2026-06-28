import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/reminder.dart';

import '../../core/theme.dart';
import '../../services/local_reminder_service.dart';

/// Section 4.3 — Reminder Detail Route & UI
class ReminderDetailScreen extends ConsumerStatefulWidget {
  const ReminderDetailScreen({super.key, required this.reminderId});
  final String reminderId;

  @override
  ConsumerState<ReminderDetailScreen> createState() =>
      _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends ConsumerState<ReminderDetailScreen> {
  bool _editing = false;
  late TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.read(localReminderServiceProvider);
    // Watches ONLY this reminder, not the whole list — fixes the white
    // screen that occurred on save, caused by every other reminder's
    // changes also forcing this screen to rebuild mid-edit.
    final reminderAsync = ref.watch(reminderProvider(widget.reminderId));

    return reminderAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Couldn\'t load this reminder: $e')),
      ),
      data: (reminder) {
        if (reminder == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Reminder not found')),
          );
        }
        return _buildDetail(context, svc, reminder);
      },
    );
  }

  Widget _buildDetail(BuildContext context, LocalReminderService svc, Reminder reminder) {
    if (!_editing && _titleCtrl.text != reminder.taskTitle) {
      _titleCtrl.text = reminder.taskTitle;
    }

    final dateFmt = DateFormat('EEEE, MMM d, y • h:mm a');
    reminder.recurrence?.timesOfDay.map((t) => t.toString()).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
            onPressed: () async {
              if (_editing) {
                // Save
                try {
                  reminder.taskTitle = _titleCtrl.text.trim();
                  await svc.updateReminder(reminder);
                  if (mounted) setState(() => _editing = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Saved')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save: $e')),
                    );
                  }
                }
              } else {
                setState(() => _editing = true);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete reminder?'),
                    content: Text('"${reminder.taskTitle}" will be removed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0584A),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await svc.deleteReminder(reminder.reminderId);
                  if (context.mounted) context.pop();
                }
              } else if (v == 'done') {
                await svc.completeReminder(reminder.reminderId);
                if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'done', child: Text('Mark done')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_editing)
            TextField(
              controller: _titleCtrl,
              style: WhisprText.body(size: 22, weight: FontWeight.w600),
              decoration: const InputDecoration(labelText: 'Task title'),
              textCapitalization: TextCapitalization.sentences,
            )
          else
            Text(reminder.taskTitle, style: WhisprText.display(size: 26)),
          const SizedBox(height: 12),

          _InfoRow(
            icon: Icons.event_rounded,
            label: 'Due',
            value: reminder.dueAt != null
                ? dateFmt.format(reminder.dueAt!)
                : 'No fixed due date',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.translate_rounded,
            label: 'Input',
            value: '${reminder.inputMethod} • ${reminder.detectedLanguage}',
          ),
          if (reminder.recurrence != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.repeat_rounded,
              label: 'Repeats',
              value:
                  '${reminder.recurrence!.type} at ${reminder.recurrence!.timesOfDay.join(', ')}',
            ),
          ],
          const SizedBox(height: 24),

          Text(
            'Notification triggers',
            style: WhisprText.body(
              size: 14,
              weight: FontWeight.w600,
              color: WhisprColors.mutedInk,
            ),
          ),
          const SizedBox(height: 10),
          ...reminder.triggers.map(
            (t) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WhisprColors.borderGray),
              ),
              child: Row(
                children: [
                  Icon(
                    t.fired
                        ? Icons.check_circle_rounded
                        : Icons.notifications_active_rounded,
                    color: t.fired
                        ? WhisprColors.calmMint
                        : WhisprColors.spokenViolet,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFmt.format(t.fireAt),
                          style: WhisprText.body(
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (t.label.isNotEmpty)
                          Text(
                            t.label,
                            style: WhisprText.body(
                              size: 13,
                              color: WhisprColors.mutedInk,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '#${t.localNotificationId}',
                    style: WhisprText.countdown(
                      size: 11,
                      color: WhisprColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (reminder.assumptionsMade.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WhisprColors.spokenViolet.withAlpha(
                  (0.07 * 255).round(),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI notes',
                    style: WhisprText.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: WhisprColors.spokenViolet,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...reminder.assumptionsMade.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• $a',
                        style: WhisprText.body(
                          size: 13,
                          color: WhisprColors.mutedInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Edit via clarification flow — Section 4.3 requirement
          OutlinedButton.icon(
            onPressed: () {
              // In V1, editing by natural language is explicitly out of scope.
              // We launch the Spark Bar pre-filled instead.
              // The Spark Bar provider in sections 1-3 exposes a method for this.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'V1 edit: change fields above, then tap ✓. Natural-language edit lands in V2.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Re-parse with AI (V2)'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: WhisprColors.mutedInk),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: WhisprText.body(size: 14, color: WhisprColors.mutedInk),
        ),
        Expanded(
          child: Text(
            value,
            style: WhisprText.body(size: 14, weight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

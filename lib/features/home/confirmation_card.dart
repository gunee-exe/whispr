import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'confirmation_card_models.dart';
import 'spark_bar_provider.dart';

/// A single card type with three states, all sharing the same visual shell
/// — Section 3.4 of the implementation plan. Background: Spoken Violet at
/// low opacity, signaling "this came from the AI".
///
/// FIX: "Edit" previously called onDismiss, which just cleared the card
/// entirely with no way to actually change anything — there was no editing
/// UI at all. This was reported as a "white screen on edit": tapping Edit
/// silently emptied the card area, which looked broken. This widget is now
/// stateful so Edit toggles an inline editable form instead.
class ConfirmationCard extends ConsumerStatefulWidget {
  final ConfirmationCardData data;
  final Future<void> Function(ConfirmationCardData) onConfirm;
  final VoidCallback onDismiss;

  /// Optional — used for the "two tasks" path so both reminders save
  /// before the UI collapses, instead of collapsing after the first one.
  /// If not provided, falls back to calling onConfirm sequentially (the
  /// old behavior, kept as a safe default for callers that haven't wired
  /// this up yet — see spark_bar_provider.dart's confirmMultipleCards).
  final Future<void> Function(List<ConfirmationCardData>)? onConfirmMultiple;

  const ConfirmationCard({
    super.key,
    required this.data,
    required this.onConfirm,
    required this.onDismiss,
    this.onConfirmMultiple,
  });

  @override
  ConsumerState<ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends ConsumerState<ConfirmationCard> {
  bool _isEditing = false;
  late TextEditingController _titleCtrl;
  DateTime? _editedDueAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.data.taskTitle ?? '');
    _editedDueAt = widget.data.dueAt;
  }

  @override
  void didUpdateWidget(ConfirmationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A genuinely new card (e.g. after a clarification round-trip produced
    // a fresh "ready" card) should reset the edit form rather than keep
    // showing stale text from the previous card.
    if (oldWidget.data != widget.data && !_isEditing) {
      _titleCtrl.text = widget.data.taskTitle ?? '';
      _editedDueAt = widget.data.dueAt;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: WhisprMotion.cardMorph,
      curve: WhisprMotion.springCurve,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WhisprColors.spokenViolet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WhisprColors.spokenViolet.withValues(alpha: 0.18)),
      ),
      child: switch (widget.data.cardType) {
        ConfirmationCardType.ready => _buildReady(context, ref),
        ConfirmationCardType.needsClarification => _buildClarification(
          context,
          ref,
        ),
        ConfirmationCardType.multiTaskDetected => _buildMultiTask(context, ref),
      },
    );
  }

  Widget _buildReady(BuildContext context, WidgetRef ref) {
    final dateFmt = _editedDueAt != null
        ? DateFormat('EEE, MMM d • h:mm a').format(_editedDueAt!)
        : null;

    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Edit reminder',
            style: WhisprText.display(size: 20, color: WhisprColors.spokenViolet),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            style: WhisprText.body(size: 18, weight: FontWeight.w600),
            decoration: const InputDecoration(labelText: 'Task title'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _editedDueAt ?? now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked == null || !context.mounted) return;
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_editedDueAt ?? now),
              );
              if (pickedTime == null) return;
              setState(() {
                _editedDueAt = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: WhisprColors.borderGray),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    dateFmt ?? 'No due date set',
                    style: WhisprText.body(size: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        final edited = _buildEditedData();
                        try {
                          await widget.onConfirm(edited);
                        } finally {
                          // Card is likely gone after a successful confirm
                          // (collapse() resets state) — guard with mounted.
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() {
                  _isEditing = false;
                  _titleCtrl.text = widget.data.taskTitle ?? '';
                  _editedDueAt = widget.data.dueAt;
                }),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Got it!',
          style: WhisprText.display(size: 22, color: WhisprColors.spokenViolet),
        ),
        const SizedBox(height: 8),
        Text(
          widget.data.taskTitle ?? 'Untitled reminder',
          style: WhisprText.body(size: 18, weight: FontWeight.w600),
        ),
        if (dateFmt != null) ...[
          const SizedBox(height: 4),
          Text(
            dateFmt,
            style: WhisprText.body(size: 14, color: WhisprColors.mutedInk),
          ),
        ],
        if (widget.data.triggers != null && widget.data.triggers!.length > 1) ...[
          const SizedBox(height: 8),
          ...widget.data.triggers!.map(
            (t) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• ${t.label}',
                style: WhisprText.body(size: 13, color: WhisprColors.mutedInk),
              ),
            ),
          ),
        ],
        if (widget.data.assumptionsMade.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...widget.data.assumptionsMade.map(
            (a) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'ℹ️ $a',
                style: WhisprText.body(
                  size: 12,
                  color: WhisprColors.mutedInk,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      try {
                        await widget.onConfirm(widget.data);
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Got it'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('Edit'),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a new ConfirmationCardData carrying the user's edits, keeping
  /// everything else (triggers, recurrence, assumptions) from the original
  /// AI response unchanged — editing the title/date shouldn't discard the
  /// AI's other structured understanding of the reminder.
  ConfirmationCardData _buildEditedData() {
    return ConfirmationCardData(
      cardType: widget.data.cardType,
      inputMethod: widget.data.inputMethod,
      originalInputText: widget.data.originalInputText,
      taskTitle: _titleCtrl.text.trim().isEmpty
          ? widget.data.taskTitle
          : _titleCtrl.text.trim(),
      dueAt: _editedDueAt,
      triggers: widget.data.triggers,
      recurrence: widget.data.recurrence,
      assumptionsMade: widget.data.assumptionsMade,
    );
  }

  Widget _buildClarification(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.data.question ?? 'Can you clarify?',
          style: WhisprText.body(size: 17, weight: FontWeight.w600),
        ),
        if (widget.data.quickReplyOptions != null &&
            widget.data.quickReplyOptions!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.data.quickReplyOptions!.map((opt) {
              return ActionChip(
                label: Text(opt, style: WhisprText.body(size: 14)),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: WhisprColors.spokenViolet.withValues(alpha: 0.3),
                ),
                onPressed: () {
                  // Carries the prior partialParse forward so the AI
                  // doesn't lose what it already understood from turn one.
                  ref
                      .read(sparkBarStateProvider.notifier)
                      .submitText(opt, clarificationContext: widget.data.partialParse);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiTask(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Looks like two things?',
          style: WhisprText.display(size: 20, color: WhisprColors.spokenViolet),
        ),
        const SizedBox(height: 12),
        if (widget.data.interpretationSingleTask != null)
          OutlinedButton(
            onPressed: () => widget.onConfirm(widget.data.interpretationSingleTask!),
            child: Text(
              'One task: "${widget.data.interpretationSingleTask!.taskTitle}"',
            ),
          ),
        const SizedBox(height: 8),
        if (widget.data.interpretationTwoTasks != null)
          ElevatedButton(
            onPressed: () async {
              final tasks = widget.data.interpretationTwoTasks!;
              // Prefer the proper multi-save path (saves all, collapses
              // once). Fall back to the old sequential-onConfirm behavior
              // only if a caller hasn't wired onConfirmMultiple up yet.
              if (widget.onConfirmMultiple != null) {
                await widget.onConfirmMultiple!(tasks);
              } else {
                for (final task in tasks) {
                  await widget.onConfirm(task);
                }
              }
            },
            child: Text(
              'Two tasks: ${widget.data.interpretationTwoTasks!.map((t) => t.taskTitle).join(" + ")}',
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'confirmation_card_models.dart';
import 'spark_bar_provider.dart';

/// A single card type with three states, all sharing the same visual shell
/// — Section 3.4 of the implementation plan. Background: Spoken Violet at
/// low opacity, signaling "this came from the AI".
class ConfirmationCard extends ConsumerWidget {
  final ConfirmationCardData data;

  const ConfirmationCard({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: WhisprMotion.cardMorph,
      curve: WhisprMotion.springCurve,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WhisprColors.spokenViolet.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WhisprColors.spokenViolet.withOpacity(0.18)),
      ),
      child: switch (data.cardType) {
        ConfirmationCardType.ready => _buildReady(context, ref),
        ConfirmationCardType.needsClarification => _buildClarification(context, ref),
        ConfirmationCardType.multiTaskDetected => _buildMultiTask(context, ref),
      },
    );
  }

  Widget _buildReady(BuildContext context, WidgetRef ref) {
    final dueAt = data.dueAt;
    final dateFmt = dueAt != null ? DateFormat('EEE, MMM d • h:mm a').format(dueAt) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Got it!', style: WhisprText.display(size: 22, color: WhisprColors.spokenViolet)),
        const SizedBox(height: 8),
        Text(data.taskTitle ?? 'Untitled reminder', style: WhisprText.body(size: 18, weight: FontWeight.w600)),
        if (dateFmt != null) ...[
          const SizedBox(height: 4),
          Text(dateFmt, style: WhisprText.body(size: 14, color: WhisprColors.mutedInk)),
        ],
        if (data.triggers != null && data.triggers!.length > 1) ...[
          const SizedBox(height: 8),
          ...data.triggers!.map((t) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• ${t.label}', style: WhisprText.body(size: 13, color: WhisprColors.mutedInk)),
              )),
        ],
        if (data.assumptionsMade.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...data.assumptionsMade.map((a) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('ℹ️ $a', style: WhisprText.body(size: 12, color: WhisprColors.mutedInk).copyWith(fontStyle: FontStyle.italic)),
              )),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => ref.read(sparkBarStateProvider.notifier).confirmCard(data),
              child: const Text('Got it'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                // Inline editing UI lands with the Reminder Detail/Edit
                // screen in Session 4 — for now, Edit dismisses back to
                // the Spark Bar with the text pre-filled isn't wired yet.
                ref.read(sparkBarStateProvider.notifier).dismissCard();
              },
              child: const Text('Edit'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClarification(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(data.question ?? 'Can you clarify?', style: WhisprText.body(size: 17, weight: FontWeight.w600)),
        if (data.quickReplyOptions != null && data.quickReplyOptions!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.quickReplyOptions!.map((opt) {
              return ActionChip(
                label: Text(opt, style: WhisprText.body(size: 14)),
                backgroundColor: Colors.white,
                side: BorderSide(color: WhisprColors.spokenViolet.withOpacity(0.3)),
                onPressed: () {
                  // Carries the prior partialParse forward so the AI
                  // doesn't lose what it already understood from turn one.
                  ref.read(sparkBarStateProvider.notifier).submitText(
                        opt,
                        clarificationContext: data.partialParse,
                      );
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
        Text('Looks like two things?', style: WhisprText.display(size: 20, color: WhisprColors.spokenViolet)),
        const SizedBox(height: 12),
        if (data.interpretationSingleTask != null)
          OutlinedButton(
            onPressed: () => ref.read(sparkBarStateProvider.notifier)
                .confirmCard(data.interpretationSingleTask!),
            child: Text('One task: "${data.interpretationSingleTask!.taskTitle}"'),
          ),
        const SizedBox(height: 8),
        if (data.interpretationTwoTasks != null)
          ElevatedButton(
            onPressed: () async {
              for (final task in data.interpretationTwoTasks!) {
                await ref.read(sparkBarStateProvider.notifier).confirmCard(task);
              }
            },
            child: Text('Two tasks: ${data.interpretationTwoTasks!.map((t) => t.taskTitle).join(" + ")}'),
          ),
      ],
    );
  }
}

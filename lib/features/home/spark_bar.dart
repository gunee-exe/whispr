import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../voice/voice_recording_provider.dart';
import 'spark_bar_provider.dart';

/// The signature interaction — Section 3.3 of the implementation plan.
/// At rest: a small, centered, pill-shaped capsule. Tapping expands it
/// into a full-width text field. Holding the mic (wired up in Session 3)
/// triggers voice mode with an amplitude-driven glow.
class SparkBar extends ConsumerStatefulWidget {
  const SparkBar({super.key});

  @override
  ConsumerState<SparkBar> createState() => _SparkBarState();
}

class _SparkBarState extends ConsumerState<SparkBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTapIdle() {
    ref.read(sparkBarStateProvider.notifier).expand();
    _focusNode.requestFocus();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(sparkBarStateProvider.notifier).submitText(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sparkBarStateProvider);
    final voiceState = ref.watch(voiceRecordingProvider);
    final isRecording = voiceState.isRecording;
    final amplitude = voiceState.amplitude;

    ref.listen<VoiceRecordingState>(voiceRecordingProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return AnimatedContainer(
      duration: WhisprMotion.sparkBarExpand,
      curve: WhisprMotion.springCurve,
      width: state.isExpanded ? double.infinity : 220,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isRecording ? WhisprColors.sparkCyan : WhisprColors.borderGray,
          width: isRecording ? 2.4 : 1,
        ),
        boxShadow: [
          if (isRecording)
            BoxShadow(
              color: WhisprColors.sparkCyan.withOpacity(0.25 + amplitude * 0.35),
              blurRadius: 16 + amplitude * 20,
              spreadRadius: 1 + amplitude * 3,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: state.isExpanded
          ? _buildExpanded(context, state, isRecording)
          : _buildIdle(context),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: _handleTapIdle,
      child: Center(
        child: Text(
          'Tell me what to remember…',
          style: WhisprText.body(size: 15, color: WhisprColors.mutedInk),
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, SparkBarState state, bool isRecording) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              enabled: !isRecording && !state.isProcessing,
              style: WhisprText.body(size: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isRecording ? 'Listening…' : 'Type a reminder…',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) => _handleSubmit(),
              textInputAction: TextInputAction.send,
            ),
          ),
          if (state.isProcessing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else ...[
            // Hold to record, release to send straight to the AI — no
            // transcript shown, the AI's interpretation IS the result
            // (Section 6.5). Tap-and-hold rather than tap-to-toggle so it
            // matches the "hold the mic" gesture described in the plan.
            GestureDetector(
              onLongPressStart: (_) async {
                await ref.read(voiceRecordingProvider.notifier).startRecording();
              },
              onLongPressEnd: (_) async {
                final path = await ref.read(voiceRecordingProvider.notifier).stopRecording();
                if (path != null) {
                  await ref.read(sparkBarStateProvider.notifier).submitVoice(path);
                }
              },
              child: IconButton(
                icon: Icon(
                  isRecording ? Icons.stop_circle : Icons.mic_none,
                  color: isRecording ? WhisprColors.sparkCyan : WhisprColors.mutedInk,
                ),
                onPressed: () {
                  // Tapping (vs holding) shows a hint — the real gesture
                  // is press-and-hold, handled above.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hold the mic to record')),
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward_rounded),
              color: WhisprColors.sparkCyan,
              onPressed: _controller.text.trim().isEmpty ? null : _handleSubmit,
            ),
          ],
        ],
      ),
    );
  }
}

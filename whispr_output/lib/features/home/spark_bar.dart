import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../voice/voice_recording_provider.dart';
import 'spark_bar_provider.dart';

/// Section 3.3 — The Spark Bar
///
/// At rest: a small pill-shaped capsule centred near the bottom of the screen.
/// Expanded: a full-width text field with keyboard.
/// Recording: Spark Cyan glow pulse tied to live mic amplitude.
///
/// This is the signature interaction of Whispr — the one element it will
/// be remembered by. Every state transition is animated.
class SparkBar extends ConsumerStatefulWidget {
  const SparkBar({super.key});

  @override
  ConsumerState<SparkBar> createState() => _SparkBarState();
}

class _SparkBarState extends ConsumerState<SparkBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barState = ref.watch(sparkBarStateProvider);
    final voiceState = ref.watch(voiceRecordingProvider);

    return AnimatedContainer(
      duration: WhisprMotion.sparkBarExpand,
      curve: WhisprMotion.springCurve,
      height: barState.isExpanded ? 56 : 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(barState.isExpanded ? 16 : 28),
        border: Border.all(
          color: voiceState.isRecording
              ? WhisprColors.sparkCyan.withOpacity(0.6 + voiceState.amplitude * 0.4)
              : WhisprColors.borderGray,
          width: voiceState.isRecording ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: voiceState.isRecording
                ? WhisprColors.sparkCyan.withOpacity(0.15 + voiceState.amplitude * 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: voiceState.isRecording
                ? 16 + voiceState.amplitude * 12
                : 8,
            spreadRadius: voiceState.isRecording ? 2 : 0,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: barState.isProcessing
                ? _buildProcessingIndicator()
                : barState.isExpanded
                    ? _buildTextField(barState)
                    : _buildPlaceholder(),
          ),
          // Mic button — hold to record, release to submit.
          if (!barState.isProcessing) _buildMicButton(voiceState, barState),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return GestureDetector(
      onTap: () => ref.read(sparkBarStateProvider.notifier).expand(),
      child: Text(
        'Tell me what to remember…',
        style: WhisprText.body(size: 15, color: WhisprColors.mutedInk),
      ),
    );
  }

  Widget _buildTextField(SparkBarState barState) {
    if (!_focusNode.hasFocus && barState.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      style: WhisprText.body(size: 15),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Tell me what to remember…',
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      textInputAction: TextInputAction.send,
      onSubmitted: (text) => _submitText(text),
      onTap: () {
        if (!ref.read(sparkBarStateProvider).isExpanded) {
          ref.read(sparkBarStateProvider.notifier).expand();
        }
      },
    );
  }

  Widget _buildProcessingIndicator() {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: WhisprColors.spokenViolet,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Parsing…',
          style: WhisprText.body(size: 14, color: WhisprColors.mutedInk),
        ),
      ],
    );
  }

  Widget _buildMicButton(VoiceRecordingState voiceState, SparkBarState barState) {
    return GestureDetector(
      onLongPressStart: (_) async {
        await ref.read(voiceRecordingProvider.notifier).startRecording();
        ref.read(sparkBarStateProvider.notifier).expand();
      },
      onLongPressEnd: (_) async {
        final path = await ref.read(voiceRecordingProvider.notifier).stopRecording();
        if (path != null) {
          await ref.read(sparkBarStateProvider.notifier).submitVoice(path);
        }
      },
      onTap: () {
        if (!barState.isExpanded) {
          ref.read(sparkBarStateProvider.notifier).expand();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: voiceState.isRecording
              ? WhisprColors.sparkCyan
              : WhisprColors.sparkCyan.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          voiceState.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          color: voiceState.isRecording ? Colors.white : WhisprColors.sparkCyan,
          size: 18,
        ),
      )
          .animate(target: voiceState.isRecording ? 1 : 0)
          .scaleXY(end: 1.1, duration: 600.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(end: 1.0, duration: 600.ms, curve: Curves.easeInOut),
    );
  }

  void _submitText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      ref.read(sparkBarStateProvider.notifier).collapse();
      return;
    }
    _textController.clear();
    ref.read(sparkBarStateProvider.notifier).submitText(trimmed);
  }
}

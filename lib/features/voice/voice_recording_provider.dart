import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Section 6.5 / Section 3.3 — Voice Recording Provider
///
/// Manages:
///   1. Mic permission state.
///   2. AudioRecorder lifecycle (start / stop).
///   3. Amplitude stream → drives the Spark Bar's Spark Cyan glow pulse.
///   4. The temporary recorded file path, passed to SparkBarNotifier once done.
///
/// No AI involvement at any point in this file — the AI call happens in
/// SparkBarNotifier.submitVoice() after this service hands off the file path.
class VoiceRecordingState {
  final bool hasPermission;
  final bool isRecording;
  /// 0.0–1.0 normalised amplitude for the glow pulse (purely visual).
  final double amplitude;
  final String? recordedFilePath;
  final String? errorMessage;

  const VoiceRecordingState({
    this.hasPermission = false,
    this.isRecording = false,
    this.amplitude = 0.0,
    this.recordedFilePath,
    this.errorMessage,
  });

  VoiceRecordingState copyWith({
    bool? hasPermission,
    bool? isRecording,
    double? amplitude,
    String? recordedFilePath,
    bool clearFile = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceRecordingState(
      hasPermission: hasPermission ?? this.hasPermission,
      isRecording: isRecording ?? this.isRecording,
      amplitude: amplitude ?? this.amplitude,
      recordedFilePath: clearFile ? null : (recordedFilePath ?? this.recordedFilePath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class VoiceRecordingNotifier extends StateNotifier<VoiceRecordingState> {
  VoiceRecordingNotifier() : super(const VoiceRecordingState()) {
    _requestPermission();
  }

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _amplitudeTimer;

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<void> _requestPermission() async {
    final hasPermission = await _recorder.hasPermission();
    state = state.copyWith(hasPermission: hasPermission);
  }

  // ---------------------------------------------------------------------------
  // Recording lifecycle
  // ---------------------------------------------------------------------------

  Future<void> startRecording() async {
    if (!state.hasPermission) {
      await _requestPermission();
      if (!state.hasPermission) {
        state = state.copyWith(
          errorMessage: 'Microphone permission required.',
        );
        return;
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/whispr_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      state = state.copyWith(isRecording: true, clearError: true);

      // Poll amplitude ~30× per second to drive the glow pulse.
      _amplitudeTimer = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) async {
          try {
            final amp = await _recorder.getAmplitude();
            // AudioRecorder returns dBFS (0 to -∞); map to [0.0, 1.0].
            // -50 dBFS as the noise floor, 0 dBFS as full.
            final norm = ((amp.current + 50.0) / 50.0).clamp(0.0, 1.0);
            state = state.copyWith(amplitude: norm);
          } catch (_) {}
        },
      );
    } catch (e, st) {
      debugPrint('VoiceRecordingNotifier.startRecording error: $e\n$st');
      state = state.copyWith(
        errorMessage: "Couldn't start recording — try again.",
        isRecording: false,
      );
    }
  }

  /// Stops recording and returns the path to the captured audio file.
  /// Returns null if recording was not in progress or an error occurred.
  Future<String?> stopRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    try {
      final path = await _recorder.stop();
      state = state.copyWith(
        isRecording: false,
        amplitude: 0.0,
        recordedFilePath: path,
      );
      return path;
    } catch (e, st) {
      debugPrint('VoiceRecordingNotifier.stopRecording error: $e\n$st');
      state = state.copyWith(
        isRecording: false,
        amplitude: 0.0,
        errorMessage: "Couldn't save the recording — try again.",
      );
      return null;
    }
  }

  /// Discards the current recording without saving it.
  Future<void> cancelRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
    state = state.copyWith(
      isRecording: false,
      amplitude: 0.0,
      clearFile: true,
      clearError: true,
    );
  }

  void clearRecordedFile() {
    state = state.copyWith(clearFile: true);
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final voiceRecordingProvider =
    StateNotifierProvider<VoiceRecordingNotifier, VoiceRecordingState>(
  (ref) => VoiceRecordingNotifier(),
);

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Mic permission state, recording amplitude stream (drives the Spark
/// Bar's glow pulse), and the recorded audio file — Section 9's
/// voiceRecordingProvider. No on-device speech recognition here at all —
/// this only captures raw audio for upload (Section 6.5).
class VoiceRecordingState {
  final bool isRecording;
  final double amplitude; // normalized 0.0–1.0
  final String? lastRecordingPath;
  final String? errorMessage;

  const VoiceRecordingState({
    this.isRecording = false,
    this.amplitude = 0.0,
    this.lastRecordingPath,
    this.errorMessage,
  });

  VoiceRecordingState copyWith({
    bool? isRecording,
    double? amplitude,
    String? lastRecordingPath,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceRecordingState(
      isRecording: isRecording ?? this.isRecording,
      amplitude: amplitude ?? this.amplitude,
      lastRecordingPath: lastRecordingPath ?? this.lastRecordingPath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class VoiceRecordingNotifier extends StateNotifier<VoiceRecordingState> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;

  VoiceRecordingNotifier() : super(const VoiceRecordingState());

  Future<bool> _ensurePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording() async {
    final granted = await _ensurePermission();
    if (!granted) {
      state = state.copyWith(errorMessage: 'Microphone permission is needed to record a reminder.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/whispr_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    if (!await _recorder.hasPermission()) {
      state = state.copyWith(errorMessage: 'Microphone permission denied.');
      return;
    }

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: path,
    );

    state = state.copyWith(isRecording: true, clearError: true);

    // Amplitude stream drives the Spark Bar's Spark-Cyan glow pulse —
    // purely visual, no AI involved at this stage (Section 3.3, 6.5).
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((amp) {
      // amp.current is in dBFS, roughly -45 (quiet) to 0 (loud).
      // Normalize to a 0.0–1.0 range for the glow.
      final normalized = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      state = state.copyWith(amplitude: normalized);
    });
  }

  /// Stops recording and returns the path to the recorded file, or null if
  /// nothing was recorded.
  Future<String?> stopRecording() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = await _recorder.stop();
    state = state.copyWith(isRecording: false, amplitude: 0.0, lastRecordingPath: path);
    return path;
  }

  Future<void> cancelRecording() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder.stop();
    state = const VoiceRecordingState();
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

final voiceRecordingProvider =
    StateNotifierProvider<VoiceRecordingNotifier, VoiceRecordingState>((ref) {
  return VoiceRecordingNotifier();
});

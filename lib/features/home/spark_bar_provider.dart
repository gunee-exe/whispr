import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The key now lives server-side on Cloudflare Workers (free tier, no card
// required) instead of inside the app — see cloudflare_worker_service.dart.
// The earlier temporary direct-in-app approach (openrouter_service.dart)
// is no longer used but kept in the project for reference.
import '../../services/cloudflare_worker_service.dart';
import '../../services/local_reminder_service.dart';
import 'confirmation_card_models.dart';

/// Drives the Spark Bar's expand/processing/card-result state — Section 9
/// of the implementation plan (sparkBarStateProvider). Recording state
/// itself (mic amplitude, is-recording) lives in voiceRecordingProvider
/// (features/voice/voice_recording_provider.dart) since that's a genuinely
/// separate concern with its own lifecycle — this notifier just consumes
/// the finished recording once it's done.
class SparkBarState {
  final bool isExpanded;
  final bool isProcessing;
  final ConfirmationCardData? cardData;
  final String? errorMessage;

  const SparkBarState({
    this.isExpanded = false,
    this.isProcessing = false,
    this.cardData,
    this.errorMessage,
  });

  SparkBarState copyWith({
    bool? isExpanded,
    bool? isProcessing,
    ConfirmationCardData? cardData,
    bool clearCard = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SparkBarState(
      isExpanded: isExpanded ?? this.isExpanded,
      isProcessing: isProcessing ?? this.isProcessing,
      cardData: clearCard ? null : (cardData ?? this.cardData),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SparkBarNotifier extends StateNotifier<SparkBarState> {
  final CloudflareWorkerService _cloudFn;
  final LocalReminderService _localService;

  SparkBarNotifier(this._cloudFn, this._localService) : super(const SparkBarState());

  void expand() {
    state = state.copyWith(isExpanded: true, clearError: true);
  }

  void collapse() {
    state = const SparkBarState();
  }

  /// Submits a recorded audio file straight to the AI — Section 6.5.
  /// No transcription step; the AI's interpretation IS the result shown.
  Future<void> submitVoice(String audioFilePath) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    try {
      final bytes = await File(audioFilePath).readAsBytes();
      final response = await _cloudFn.callAIWithAudio(
        audioBytes: bytes,
        mimeType: 'audio/m4a',
      );
      final card = ConfirmationCardData.fromAiResponse(
        response,
        inputMethod: 'voice',
        originalInputText: '[voice]',
      );
      state = state.copyWith(isProcessing: false, cardData: card);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: "Didn't catch that — try again?",
      );
    } finally {
      // Clean up the temp recording regardless of success/failure — it's
      // never persisted (Section 5.1: no transcript or audio is stored).
      try {
        final f = File(audioFilePath);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Non-fatal — temp dir gets cleared by the OS eventually anyway.
      }
    }
  }

  /// Submits typed text to the AI pipeline — Session 2 scope.
  /// [clarificationContext] carries the prior partialParse forward when
  /// this submission is a reply to a needs_clarification card, so the AI
  /// doesn't lose what it already understood (Section 6.1).
  Future<void> submitText(String text, {Map<String, dynamic>? clarificationContext}) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    try {
      final response = await _cloudFn.callAI(
        inputText: text,
        currentClarificationContext: clarificationContext,
      );
      final card = ConfirmationCardData.fromAiResponse(
        response,
        inputMethod: 'text',
        originalInputText: text,
      );
      state = state.copyWith(isProcessing: false, cardData: card);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: "Couldn't reach the AI — check your connection and try again.",
      );
    }
  }

  /// Called when the user confirms the card as-is, or after editing it.
  Future<void> confirmCard(ConfirmationCardData finalData) async {
    await _localService.saveReminderFromCard(finalData);
    collapse();
  }

  void dismissCard() {
    state = state.copyWith(clearCard: true);
  }
}

final sparkBarStateProvider =
    StateNotifierProvider<SparkBarNotifier, SparkBarState>((ref) {
  return SparkBarNotifier(
    ref.watch(cloudflareWorkerServiceProvider),
    ref.watch(localReminderServiceProvider),
  );
});

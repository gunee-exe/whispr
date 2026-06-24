import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps the ONE Cloud Function this app has — callAI (Section 8 of the
/// implementation plan). It holds the OpenRouter key server-side and
/// forwards either typed text or a recorded audio clip; it does not save
/// anything or know about reminders.
class CloudFunctionService {
  final FirebaseFunctions _functions;

  CloudFunctionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Text input path (Session 2). Returns the raw JSON map matching one of
  /// the three response shapes in Section 6.3.
  Future<Map<String, dynamic>> callAI({
    required String inputText,
    Map<String, dynamic>? currentClarificationContext,
  }) async {
    final callable = _functions.httpsCallable('callAI');
    final result = await callable.call<Map<String, dynamic>>({
      'inputType': 'text',
      'text': inputText,
      'deviceTimezone': DateTime.now().timeZoneName,
      'currentDateTime': DateTime.now().toIso8601String(),
      if (currentClarificationContext != null)
        'currentClarificationContext': currentClarificationContext,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Voice input path (Session 3). Sends the recorded audio clip directly —
  /// no transcription step, see Section 6.5.
  Future<Map<String, dynamic>> callAIWithAudio({
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    final callable = _functions.httpsCallable('callAI');
    final result = await callable.call<Map<String, dynamic>>({
      'inputType': 'voice',
      'audioData': base64Encode(audioBytes),
      'mimeType': mimeType,
      'deviceTimezone': DateTime.now().timeZoneName,
      'currentDateTime': DateTime.now().toIso8601String(),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}

final cloudFunctionServiceProvider = Provider<CloudFunctionService>((ref) {
  return CloudFunctionService();
});

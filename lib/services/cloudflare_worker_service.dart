import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Wraps the ONE server-side function this app has — callAI, now hosted
/// on Cloudflare Workers instead of Firebase Cloud Functions (Section 8 of
/// the implementation plan, same architecture, different host). It holds
/// the OpenRouter key server-side and forwards either typed text or a
/// recorded audio clip; it does not save anything or know about reminders.
///
/// Same public method names/signatures as the old CloudFunctionService
/// (cloud_function_service.dart, kept in the project but currently
/// unused) — so switching providers in spark_bar_provider.dart is the
/// only change needed if you ever want to swap hosting again.
class CloudflareWorkerService {
  // Set this to your deployed Worker's URL after running `wrangler deploy`
  // — it'll print something like https://whispr-callai.YOUR-SUBDOMAIN.workers.dev
  static const String _workerUrl = 'https://whispr-callai.gunee-exe-whispr.workers.dev';

  final http.Client _client;

  CloudflareWorkerService({http.Client? client}) : _client = client ?? http.Client();

  /// Text input path (Session 2). Returns the raw JSON map matching one of
  /// the three response shapes in Section 6.3.
  Future<Map<String, dynamic>> callAI({
    required String inputText,
    Map<String, dynamic>? currentClarificationContext,
  }) async {
    final now = DateTime.now();
    return _post({
      'inputType': 'text',
      'text': inputText,
      'deviceTimezone': _utcOffsetString(now),
      'currentDateTime': _isoWithOffset(now),
      if (currentClarificationContext != null)
        'currentClarificationContext': currentClarificationContext,
    });
  }

  /// Voice input path (Session 3). Sends the recorded audio clip directly —
  /// no transcription step, see Section 6.5.
  Future<Map<String, dynamic>> callAIWithAudio({
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    final now = DateTime.now();
    return _post({
      'inputType': 'voice',
      'audioData': base64Encode(audioBytes),
      'mimeType': mimeType,
      'deviceTimezone': _utcOffsetString(now),
      'currentDateTime': _isoWithOffset(now),
    });
  }

  /// Returns a numeric UTC offset like "+05:00" or "-04:30" — something the
  /// AI can use mechanically with zero inference, unlike DateTime.timeZoneName
  /// (which can return ambiguous OS-level abbreviations such as "PKT" or a
  /// generic "GMT+5" depending on device/OS, and was the root cause of
  /// reminders displaying in UTC instead of local time).
  static String _utcOffsetString(DateTime localNow) {
    final offset = localNow.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }

  /// DateTime.now().toIso8601String() omits the UTC offset entirely for
  /// local DateTimes, leaving the anchor date/time itself ambiguous to the
  /// model. This appends the real offset explicitly.
  static String _isoWithOffset(DateTime localNow) {
    final base = localNow.toIso8601String(); // e.g. "2026-06-26T21:18:00.123456"
    final noMicros = base.split('.').first; // strip fractional seconds
    return '$noMicros${_utcOffsetString(localNow)}';
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    if (_workerUrl == 'PASTE_YOUR_WORKER_URL_HERE') {
      throw StateError(
        'Cloudflare Worker URL not set. Open lib/services/cloudflare_worker_service.dart '
        'and paste your deployed Worker URL into _workerUrl.',
      );
    }

    final response = await _client.post(
      Uri.parse(_workerUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(decoded['error'] ?? 'Worker returned ${response.statusCode}');
    }

    return decoded;
  }
}

final cloudflareWorkerServiceProvider = Provider<CloudflareWorkerService>((ref) {
  return CloudflareWorkerService();
});

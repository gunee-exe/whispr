import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Section 7.5 / 7.6 — Live Activity Bridge
///
/// Wraps the native platform channels for:
///   • iOS: ActivityKit via the custom Swift plugin in ios/Runner/LiveActivityPlugin.swift
///   • Android: Foreground Service via the CountdownForegroundService in
///     android/app/src/main/kotlin/.../CountdownForegroundService.kt
///
/// The Dart layer is intentionally thin — it only serializes the payload and
/// dispatches it through the channel. All rendering logic lives natively.
class LiveActivityService {
  // Must match the channel name registered in AppDelegate.swift and
  // MainActivity.kt respectively.
  static const MethodChannel _channel = MethodChannel(
    'com.whispr.app/live_activity',
  );

  // Suppresses repeated log spam when the native plugin isn't registered
  // (e.g. on simulator without the Swift plugin wired up).
  static bool _pluginWarningLogged = false;

  void _logMissingPlugin(String method) {
    if (!_pluginWarningLogged) {
      debugPrint('LiveActivityService: native plugin not registered — Live Activity calls are no-ops on this device/simulator.');
      _pluginWarningLogged = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Single trigger Live Activity
  // ---------------------------------------------------------------------------

  /// Starts (or updates, if one already exists for this trigger) a Live
  /// Activity showing a single countdown ring.
  ///
  /// On iOS: calls ActivityKit to start/update the SwiftUI widget extension.
  /// On Android: sends an Intent to CountdownForegroundService to start/update
  /// the ongoing notification.
  Future<void> startOrUpdateSingleActivity({
    required String reminderId,
    required String triggerId,
    required String title,
    required DateTime fireAt,
    required String label,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startSingleActivity', {
        'reminderId': reminderId,
        'triggerId': triggerId,
        'title': title,
        // Sent as UTC ("...Z") rather than a local-no-offset string —
        // this is the one unambiguous format every native parser
        // (Kotlin's OffsetDateTime.parse, Swift's ISO8601DateFormatter)
        // accepts without guessing. fireAt is normalized to local for
        // in-app DISPLAY elsewhere (see confirmation_card_models.dart's
        // .toLocal() calls); .toUtc() here just converts that same
        // instant back for transport — the underlying moment in time
        // is unchanged either way.
        'fireAt': fireAt.toUtc().toIso8601String(),
        'label': label,
      });
    } on MissingPluginException {
      _logMissingPlugin('startSingleActivity');
    } on PlatformException catch (e, st) {
      debugPrint('LiveActivityService.startOrUpdateSingleActivity error: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // Merged Live Activity (Section 7.4)
  // ---------------------------------------------------------------------------

  /// Starts (or updates) a merged Live Activity when 2+ triggers fall within
  /// the same 2-hour window. Shows a count and the nearest task's name/time.
  Future<void> startOrUpdateMergedActivity({
    required int count,
    required String nearestTitle,
    required DateTime nearestFireAt,
    required String activityId,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startMergedActivity', {
        'activityId': activityId,
        'count': count,
        'nearestTitle': nearestTitle,
        // See the comment in startOrUpdateSingleActivity above — same
        // unambiguous-UTC-for-transport reasoning applies here.
        'nearestFireAt': nearestFireAt.toUtc().toIso8601String(),
      });
    } on MissingPluginException {
      _logMissingPlugin('startMergedActivity');
    } on PlatformException catch (e, st) {
      debugPrint('LiveActivityService.startOrUpdateMergedActivity error: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // End activities
  // ---------------------------------------------------------------------------

  /// Ends the Live Activity for a specific trigger (called when the trigger fires).
  Future<void> endActivity({required String triggerId}) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('endActivity', {'triggerId': triggerId});
    } on MissingPluginException {
      _logMissingPlugin('endActivity');
    } on PlatformException catch (e, st) {
      debugPrint('LiveActivityService.endActivity error: $e\n$st');
    }
  }

  /// Ends ALL active Live Activities / ongoing notifications.
  /// Called when no upcoming triggers remain.
  Future<void> endAllActivities() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('endAllActivities');
    } on MissingPluginException {
      _logMissingPlugin('endAllActivities');
    } on PlatformException catch (e, st) {
      debugPrint('LiveActivityService.endAllActivities error: $e\n$st');
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  return LiveActivityService();
});

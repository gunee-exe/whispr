// ios/Runner/AppDelegate.swift
//
// Platform channel bridge between Flutter (LiveActivityService.dart) and
// iOS ActivityKit (WhisprLiveActivity.swift in the WhisprWidget extension).
//
// Replace the existing AppDelegate.swift in ios/Runner/ with this file.
// The Flutter-generated @main AppDelegate is preserved below
// with the channel handler added.

import UIKit
import Flutter
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        // Wire up the Live Activity platform channel.
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let channel = FlutterMethodChannel(
            name: "com.whispr.app/live_activity",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "startSingleActivity":
                self.handleStartSingle(call.arguments, result: result)
            case "startMergedActivity":
                self.handleStartMerged(call.arguments, result: result)
            case "endActivity":
                self.handleEnd(call.arguments, result: result)
            case "endAllActivities":
                self.handleEndAll(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Handlers

    private func handleStartSingle(_ args: Any?, result: FlutterResult) {
        guard
            let map = args as? [String: Any],
            let reminderId = map["reminderId"] as? String,
            let triggerId  = map["triggerId"] as? String,
            let title      = map["title"] as? String,
            let fireAtStr  = map["fireAt"] as? String,
            let fireAt     = ISO8601DateFormatter().date(from: fireAtStr),
            let label      = map["label"] as? String
        else {
            result(FlutterError(code: "BAD_ARGS", message: "Missing required fields", details: nil))
            return
        }

        let activityId = "single_\(triggerId)"
        let attributes = WhisprActivityAttributes(activityId: activityId)
        let state = WhisprActivityAttributes.ContentState(
            taskTitle: title,
            fireAt: fireAt,
            label: label,
            isMerged: false,
            mergedCount: 1
        )

        do {
            if #available(iOS 16.2, *) {
                let activity = try Activity<WhisprActivityAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
                result(activity.id)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.2+ required", details: nil))
            }
        } catch {
            result(FlutterError(code: "ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func handleStartMerged(_ args: Any?, result: FlutterResult) {
        guard
            let map          = args as? [String: Any],
            let activityId   = map["activityId"] as? String,
            let count        = map["count"] as? Int,
            let nearestTitle = map["nearestTitle"] as? String,
            let fireAtStr    = map["nearestFireAt"] as? String,
            let fireAt       = ISO8601DateFormatter().date(from: fireAtStr)
        else {
            result(FlutterError(code: "BAD_ARGS", message: "Missing required fields", details: nil))
            return
        }

        let attributes = WhisprActivityAttributes(activityId: activityId)
        let state = WhisprActivityAttributes.ContentState(
            taskTitle: nearestTitle,
            fireAt: fireAt,
            label: "",
            isMerged: true,
            mergedCount: count
        )

        do {
            if #available(iOS 16.2, *) {
                let activity = try Activity<WhisprActivityAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
                result(activity.id)
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.2+ required", details: nil))
            }
        } catch {
            result(FlutterError(code: "ACTIVITY_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func handleEnd(_ args: Any?, result: @escaping FlutterResult) {
        guard let map = args as? [String: Any],
              let triggerId = map["triggerId"] as? String
        else {
            result(FlutterError(code: "BAD_ARGS", message: "Missing triggerId", details: nil))
            return
        }

        if #available(iOS 16.2, *) {
            Task {
                for activity in Activity<WhisprActivityAttributes>.activities
                where activity.attributes.activityId.contains(triggerId) {
                    await activity.end(dismissalPolicy: .immediate)
                }
                result(nil)
            }
        } else {
            result(nil)
        }
    }

    private func handleEndAll(result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            Task {
                for activity in Activity<WhisprActivityAttributes>.activities {
                    await activity.end(dismissalPolicy: .immediate)
                }
                result(nil)
            }
        } else {
            result(nil)
        }
    }
}

// Struct definition duplicated here for Runner target compile visibility.
struct WhisprActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var fireAt: Date
        var label: String
        var isMerged: Bool
        var mergedCount: Int
    }

    var activityId: String
}

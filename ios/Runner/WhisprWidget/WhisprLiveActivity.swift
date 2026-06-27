// ios/Runner/WhisprWidget/WhisprLiveActivity.swift
//
// Section 7.5 — iOS Live Activity (ActivityKit + SwiftUI)
//
// This file is a SEPARATE XCODE TARGET ("WhisprWidget") — it does NOT run
// inside the Flutter app's main target. It is a Widget Extension.
//
// Integration with Flutter:
//   The Flutter side (LiveActivityService.dart) calls through the
//   "com.whispr.app/live_activity" MethodChannel. The AppDelegate.swift
//   (in the main Runner target) receives those calls and forwards them to
//   ActivityKit using this file's data types.

import ActivityKit
import SwiftUI
import WidgetKit

// ---------------------------------------------------------------------------
// MARK: - Activity Attributes (the "shape" of the Live Activity data)
// ---------------------------------------------------------------------------

struct WhisprActivityAttributes: ActivityAttributes {
    // Static data that doesn't change while the Live Activity is running.
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var fireAt: Date
        var label: String
        var isMerged: Bool
        var mergedCount: Int
    }

    var activityId: String
}

// ---------------------------------------------------------------------------
// MARK: - Live Activity Widget View
// ---------------------------------------------------------------------------

@available(iOSApplicationExtension 16.2, *)
struct WhisprLiveActivityView: View {
    let context: ActivityViewContext<WhisprActivityAttributes>

    var body: some View {
        let state = context.state

        // Canonical Whispr color palette — must match theme.dart exactly.
        let spokenViolet = Color(red: 0.486, green: 0.435, blue: 0.941)
        let sparkCyan    = Color(red: 0.0,   green: 0.761, blue: 0.820)
        let emberAmber   = Color(red: 1.0,   green: 0.820, blue: 0.400)
        let calmMint     = Color(red: 0.659, green: 0.902, blue: 0.812)
        let morningPaper = Color(red: 1.0,   green: 0.973, blue: 0.941)
        let plumInk      = Color(red: 0.176, green: 0.165, blue: 0.239)

        VStack(spacing: 8) {
            if state.isMerged {
                // Section 7.4 — Merged view.
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(sparkCyan)
                    Text("\(state.mergedCount) things due soon")
                        .font(.headline)
                        .foregroundColor(plumInk)
                    Spacer()
                    CountdownLabel(fireAt: state.fireAt, color: emberAmber)
                }
                Text("Next: \(state.taskTitle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                // Single task view with countdown ring.
                HStack(alignment: .center, spacing: 16) {
                    CountdownRingView(
                        fireAt: state.fireAt,
                        size: 60,
                        calmMint: calmMint,
                        emberAmber: emberAmber,
                        sparkCyan: sparkCyan
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.taskTitle)
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(plumInk)
                            .lineLimit(2)
                        if !state.label.isEmpty {
                            Text(state.label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    CountdownLabel(fireAt: state.fireAt, color: emberAmber)
                }
            }
        }
        .padding()
        .background(morningPaper)
    }
}

// ---------------------------------------------------------------------------
// MARK: - Sub-views
// ---------------------------------------------------------------------------

@available(iOSApplicationExtension 16.2, *)
struct CountdownLabel: View {
    let fireAt: Date
    let color: Color

    var body: some View {
        Text(fireAt, style: .timer)
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .foregroundColor(color)
            .monospacedDigit()
    }
}

@available(iOSApplicationExtension 16.2, *)
struct CountdownRingView: View {
    let fireAt: Date
    let size: CGFloat
    let calmMint: Color
    let emberAmber: Color
    let sparkCyan: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: size * 0.08)
            Circle()
                .trim(from: 0, to: progressFraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [calmMint, emberAmber, sparkCyan]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: size * 0.08,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1), value: progressFraction)

            Text(fireAt, style: .timer)
                .font(.system(size: size * 0.18, design: .monospaced).weight(.semibold))
                .foregroundColor(emberAmber)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }

    private var progressFraction: Double {
        let remaining = fireAt.timeIntervalSinceNow
        guard remaining > 0 else { return 1.0 }
        let window: Double = 30 * 60 // 30 min default
        return min(1.0, 1.0 - remaining / window)
    }
}

// ---------------------------------------------------------------------------
// MARK: - Widget Extension Entry Point
// ---------------------------------------------------------------------------

@available(iOSApplicationExtension 16.2, *)
struct WhisprWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WhisprActivityAttributes.self) { context in
            // Lock-screen / banner view.
            WhisprLiveActivityView(context: context)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                // Expanded dynamic island.
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.761, blue: 0.820))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.taskTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.fireAt, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Color(red: 1.0, green: 0.820, blue: 0.400))
                }
            } compactLeading: {
                Image(systemName: "bell.fill")
                    .foregroundColor(Color(red: 0.0, green: 0.761, blue: 0.820))
            } compactTrailing: {
                Text(state.fireAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(Color(red: 1.0, green: 0.820, blue: 0.400))
            } minimal: {
                Image(systemName: "bell.fill")
                    .foregroundColor(Color(red: 0.0, green: 0.761, blue: 0.820))
            }
        }
    }
}

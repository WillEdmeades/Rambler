import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

/// Shows the current capture state on the Lock Screen and in the Dynamic Island.
struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingLiveActivityAttributes.self) { context in
            RecordingLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(context.state.isPaused ? .orange : .red)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(statusTitle(for: context), systemImage: context.state.isPaused ? "pause.fill" : "mic.fill")
                        .font(.headline)
                        .foregroundStyle(context.state.isPaused ? .orange : .red)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(RecordingLiveActivityFormatter.clockText(context.state.elapsedSeconds))
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.sessionTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        if context.state.isTranscriptFallbackActive {
                            Text("Transcript will finish after capture.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                    .foregroundStyle(context.state.isPaused ? .orange : .red)
            } compactTrailing: {
                Text(RecordingLiveActivityFormatter.compactClockText(context.state.elapsedSeconds))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                    .foregroundStyle(context.state.isPaused ? .orange : .red)
            }
            .keylineTint(context.state.isPaused ? .orange : .red)
        }
    }

    private func statusTitle(for context: ActivityViewContext<RecordingLiveActivityAttributes>) -> String {
        if context.state.isPaused {
            return "Paused"
        }

        return context.state.statusText
    }
}

private struct RecordingLiveActivityLockScreenView: View {
    let context: ActivityViewContext<RecordingLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(context.state.isPaused ? "Paused" : "Recording", systemImage: context.state.isPaused ? "pause.fill" : "mic.fill")
                    .font(.headline)
                    .foregroundStyle(context.state.isPaused ? .orange : .red)

                Spacer()

                Text(RecordingLiveActivityFormatter.clockText(context.state.elapsedSeconds))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
            }

            Text(context.attributes.sessionTitle)
                .font(.body.weight(.semibold))
                .lineLimit(2)

            if context.state.isTranscriptFallbackActive {
                Text("Transcript will be ready after capture finishes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private enum RecordingLiveActivityFormatter {
    static func clockText(_ elapsedSeconds: TimeInterval) -> String {
        let totalSeconds = max(Int(elapsedSeconds.rounded(.down)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func compactClockText(_ elapsedSeconds: TimeInterval) -> String {
        let totalSeconds = max(Int(elapsedSeconds.rounded(.down)), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Lock Screen", as: .content, using: RecordingLiveActivityAttributes.preview) {
    RecordingLiveActivityWidget()
} contentStates: {
    RecordingLiveActivityAttributes.ContentState.recording
    RecordingLiveActivityAttributes.ContentState.paused
}

#Preview(
    "Dynamic Island Expanded",
    as: .dynamicIsland(.expanded),
    using: RecordingLiveActivityAttributes.preview
) {
    RecordingLiveActivityWidget()
} contentStates: {
    RecordingLiveActivityAttributes.ContentState.recording
}

#Preview(
    "Dynamic Island Compact",
    as: .dynamicIsland(.compact),
    using: RecordingLiveActivityAttributes.preview
) {
    RecordingLiveActivityWidget()
} contentStates: {
    RecordingLiveActivityAttributes.ContentState.recording
}

#Preview(
    "Dynamic Island Minimal",
    as: .dynamicIsland(.minimal),
    using: RecordingLiveActivityAttributes.preview
) {
    RecordingLiveActivityWidget()
} contentStates: {
    RecordingLiveActivityAttributes.ContentState.paused
}

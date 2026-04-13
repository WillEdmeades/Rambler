import Foundation
import OSLog
import ActivityKit

@MainActor
final class RecordingLiveActivityManager {
    private var activity: Activity<RecordingLiveActivityAttributes>?
    private let logger = Logger(subsystem: "com.WillEdmeades.Rambler", category: "RecordingLiveActivity")

    func start(title: String, elapsedSeconds: TimeInterval, stateLabel: String, isPaused: Bool, isTranscriptFallbackActive: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        do {
            let attributes = RecordingLiveActivityAttributes(sessionTitle: title)
            let content = ActivityContent(
                state: RecordingLiveActivityAttributes.ContentState(
                    statusText: stateLabel,
                    elapsedSeconds: elapsedSeconds,
                    isPaused: isPaused,
                    isTranscriptFallbackActive: isTranscriptFallbackActive
                ),
                staleDate: nil
            )
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(elapsedSeconds: TimeInterval, stateLabel: String, isPaused: Bool, isTranscriptFallbackActive: Bool) async {
        guard let activity else { return }

        let content = ActivityContent(
            state: RecordingLiveActivityAttributes.ContentState(
                statusText: stateLabel,
                elapsedSeconds: elapsedSeconds,
                isPaused: isPaused,
                isTranscriptFallbackActive: isTranscriptFallbackActive
            ),
            staleDate: nil
        )

        await activity.update(content)
    }

    func end() async {
        guard let activity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}

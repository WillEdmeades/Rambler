import Foundation

#if os(iOS)
import ActivityKit

/// Shared attributes used by Rambler's recording Live Activity.
struct RecordingLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var statusText: String
        var elapsedSeconds: TimeInterval
        var isPaused: Bool
        var isTranscriptFallbackActive: Bool
    }

    var sessionTitle: String
}

#if DEBUG
extension RecordingLiveActivityAttributes {
    static var preview: RecordingLiveActivityAttributes {
        RecordingLiveActivityAttributes(sessionTitle: "Weekly 1:1")
    }
}

extension RecordingLiveActivityAttributes.ContentState {
    static var recording: RecordingLiveActivityAttributes.ContentState {
        RecordingLiveActivityAttributes.ContentState(
            statusText: "Recording",
            elapsedSeconds: 305,
            isPaused: false,
            isTranscriptFallbackActive: false
        )
    }

    static var paused: RecordingLiveActivityAttributes.ContentState {
        RecordingLiveActivityAttributes.ContentState(
            statusText: "Paused",
            elapsedSeconds: 305,
            isPaused: true,
            isTranscriptFallbackActive: false
        )
    }
}
#endif
#endif

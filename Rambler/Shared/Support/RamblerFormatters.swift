import Foundation

enum RamblerFormatters {
    private static let sessionDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private static let accessibilityDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 3
        return formatter
    }()

    static func sessionDuration(_ duration: TimeInterval) -> String {
        sessionDurationFormatter.string(from: duration) ?? "0:00"
    }

    static func recordingClock(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func accessibilityDuration(_ duration: TimeInterval) -> String {
        accessibilityDurationFormatter.string(from: duration) ?? "0 seconds"
    }
}

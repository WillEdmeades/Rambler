import Foundation

struct CaptureConfiguration: Equatable, Hashable, Sendable {
    var title: String
    var localeIdentifier: String

    init(title: String = "", localeIdentifier: String = "en-US") {
        self.title = title
        self.localeIdentifier = localeIdentifier
    }

    var normalizedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Conversation" : trimmed
    }
}

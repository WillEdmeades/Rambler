import Foundation

struct ReviewArtifact: Codable, Equatable, Sendable {
    var proseSummary: String?
    var summaryItems: [SummaryItem]

    var isEmpty: Bool {
        normalizedProseSummary == nil && summaryItems.isEmpty
    }

    var normalizedProseSummary: String? {
        let trimmed = proseSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    init(proseSummary: String? = nil, summaryItems: [SummaryItem] = []) {
        self.proseSummary = proseSummary
        self.summaryItems = summaryItems
    }
}

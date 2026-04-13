import Foundation
import Testing
@testable import Rambler

struct StorageServiceTests {
    @Test
    func reviewArtifactRoundTripsProseSummaryAndStructuredItems() throws {
        let uuid = UUID()
        let item = SummaryItem(
            content: "Keep the transcript central.",
            type: .overview,
            sourceSegmentIDs: [UUID()]
        )

        let url = try StorageService.shared.saveReview(
            ReviewArtifact(
                proseSummary: "The vendor walkthrough moved to Thursday while the notes stayed brief.",
                summaryItems: [item]
            ),
            uuid: uuid
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let review = try #require(StorageService.shared.loadReview(from: url))

        #expect(review.normalizedProseSummary == "The vendor walkthrough moved to Thursday while the notes stayed brief.")
        #expect(review.summaryItems == [item])
    }

    @Test
    func loadReviewSupportsLegacySummaryOnlyFiles() throws {
        let uuid = UUID()
        let artifactDirectory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Artifacts", isDirectory: true)
        let url = artifactDirectory.appendingPathComponent("\(uuid.uuidString)_summaries.json")
        let legacyItems = [
            SummaryItem(content: "Call the florist after the permit is approved.", type: .actionItem, actionStatus: .todo)
        ]

        try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(legacyItems).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let review = try #require(StorageService.shared.loadReview(from: url))

        #expect(review.normalizedProseSummary == nil)
        #expect(review.summaryItems == legacyItems)
    }
}

import Foundation
import FoundationModels
import Testing
@testable import Rambler

@MainActor
private struct StubLanguageModelProvider: LanguageModelProvider {
    let availability: (Bool, String)
    let generatedText: String

    func isAvailable() async -> (Bool, String) {
        availability
    }

    func generate<Content: Generable & Sendable>(
        prompt: String,
        instructions: String,
        generating type: Content.Type
    ) async throws -> Content {
        fatalError("This test double does not support guided generation.")
    }

    func generateText(
        prompt: String,
        instructions: String
    ) async throws -> String {
        generatedText
    }
}

@MainActor
struct SummaryServiceTests {
    @Test
    func askRamblerReturnsTemporaryAnswerWithMatchedSourceEvidence() async throws {
        let segment = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
            startTime: 12,
            endTime: 20,
            text: "Let's move the vendor walkthrough to Thursday after finance signs off.",
            isFinal: true
        )
        let item = SummaryItem(
            content: "Vendor walkthrough: Move the walkthrough to Thursday after finance signs off.",
            type: .decision,
            sourceSegmentIDs: [segment.id]
        )
        let service = SummaryService(
            languageModel: StubLanguageModelProvider(
                availability: (true, "Available"),
                generatedText: "The vendor walkthrough will move to Thursday after finance signs off."
            )
        )

        let result = await service.askRambler(
            question: "What was decided?",
            title: "Decisions",
            reviewSummary: nil,
            summaryItems: [item],
            segments: [segment]
        )

        switch result {
        case .success(let response):
            #expect(response.title == "Decisions")
            #expect(response.answer == "The vendor walkthrough will move to Thursday after finance signs off.")
            #expect(response.sourceSegmentIDs == [segment.id])
        case .failure(let error):
            Issue.record("Expected success but got failure: \(error.localizedDescription)")
        }
    }
}

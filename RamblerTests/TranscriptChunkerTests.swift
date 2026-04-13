import Foundation
import Testing
@testable import Rambler

struct TranscriptChunkerTests {
    @Test
    func splitsTranscriptIntoOverlappingChunks() {
        let segments = [
            TranscriptSegment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                startTime: 0,
                endTime: 5,
                text: "one two three four five",
                isFinal: true
            ),
            TranscriptSegment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                startTime: 5,
                endTime: 10,
                text: "six seven eight nine ten",
                isFinal: true
            ),
            TranscriptSegment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                startTime: 10,
                endTime: 15,
                text: "eleven twelve thirteen fourteen fifteen",
                isFinal: true
            )
        ]

        let chunker = TranscriptChunker(maxTokens: 20, overlapTokens: 10)
        let chunks = chunker.generateChunks(from: segments)

        #expect(chunks.count == 2)
        #expect(chunks[0].segments.map(\.id) == [segments[0].id, segments[1].id])
        #expect(chunks[1].segments.map(\.id) == [segments[1].id, segments[2].id])
        #expect(chunks[0].approximateTokenCount == 20)
        #expect(chunks[1].approximateTokenCount == 20)
    }

    @Test
    func returnsNoChunksForAnEmptyTranscript() {
        let chunker = TranscriptChunker(maxTokens: 20, overlapTokens: 10)

        #expect(chunker.generateChunks(from: []).isEmpty)
    }
}

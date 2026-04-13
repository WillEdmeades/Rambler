import Foundation
import Testing
@testable import Rambler

struct ExportServiceTests {
    @Test
    func fullSessionMarkdownIncludesReviewSummaryBeforeStructuredSections() throws {
        let recording = Recording(
            title: "Review Export",
            timestamp: Date(timeIntervalSince1970: 1_736_164_800),
            duration: 210
        )
        let segments = [
            TranscriptSegment(startTime: 0, endTime: 10, text: "The vendor packet needs a shorter intro and a clearer timeline.", isFinal: true)
        ]
        let summaries = [
            SummaryItem(content: "The vendor packet should be shorter and easier to scan.", type: .overview)
        ]

        let url = try ExportService.shared.generateMarkdown(
            for: recording,
            segments: segments,
            reviewSummary: "The vendor packet needs a shorter intro and a clearer timeline before it goes out.",
            summaries: summaries
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        let summaryRange = try #require(content.range(of: "## Summary"))
        let keyPointsRange = try #require(content.range(of: "## Key Points"))

        #expect(content.contains("The vendor packet needs a shorter intro and a clearer timeline before it goes out."))
        #expect(summaryRange.lowerBound < keyPointsRange.lowerBound)
    }

    @Test
    func summaryNotesMarkdownExcludesActionsAndTranscript() throws {
        let recording = Recording(
            title: "Design/Review: Alpha",
            timestamp: Date(timeIntervalSince1970: 1_736_164_800),
            duration: 125
        )
        let segments = [
            TranscriptSegment(startTime: 0, endTime: 10, text: "The lease photos should happen on Thursday afternoon.", isFinal: true),
            TranscriptSegment(startTime: 10, endTime: 20, text: "I will send the revised shot list by tonight.", isFinal: true)
        ]
        let summaries = [
            SummaryItem(content: "The lease photos should move to Thursday afternoon.", type: .overview),
            SummaryItem(content: "Send the revised shot list.", type: .actionItem, actionStatus: .todo)
        ]

        let url = try ExportService.shared.generateMarkdown(
            for: recording,
            segments: segments,
            summaries: summaries,
            scope: .summaryNotes
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("## Key Points"))
        #expect(content.contains("The lease photos should move to Thursday afternoon."))
        #expect(!content.contains("Send the revised shot list."))
        #expect(!content.contains("## Transcript"))
        #expect(url.lastPathComponent.hasSuffix(" Summary.md"))
    }

    @Test
    func actionsOnlyPlainTextUsesChecklistFormatting() throws {
        let recording = Recording(
            title: "Weekly Debrief",
            timestamp: Date(timeIntervalSince1970: 1_736_164_800),
            duration: 180
        )
        let segments = [
            TranscriptSegment(startTime: 0, endTime: 10, text: "Send the revised lease packet this afternoon.", isFinal: true)
        ]
        let summaries = [
            SummaryItem(content: "The lease packet needs one more pass.", type: .overview),
            SummaryItem(content: "Send the recap by Friday.", type: .actionItem, actionStatus: .done)
        ]

        let url = try ExportService.shared.generatePlainText(
            for: recording,
            segments: segments,
            summaries: summaries,
            scope: .actionsOnly
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("Actions"))
        #expect(content.contains("- [x] Send the recap by Friday."))
        #expect(!content.contains("The lease packet needs one more pass."))
        #expect(!content.contains("Transcript"))
        #expect(url.lastPathComponent.hasSuffix(" Actions.txt"))
    }
}

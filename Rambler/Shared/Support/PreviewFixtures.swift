import Foundation
import SwiftData

@MainActor
enum PreviewFixtures {
    private static let previewDate = Date(timeIntervalSince1970: 1_736_164_800)

    static let sampleTranscriptSegments: [TranscriptSegment] = [
        TranscriptSegment(startTime: 0, endTime: 12, text: "The guest room paint is dry, but the desk still needs to be assembled.", isFinal: true),
        TranscriptSegment(startTime: 12, endTime: 26, text: "Let's move the photo shoot to Thursday morning so the room can air out overnight.", isFinal: true),
        TranscriptSegment(startTime: 26, endTime: 39, text: "I'll send the revised shot list tonight and borrow the floor lamp from the studio.", isFinal: true)
    ]

    static let sampleSummaryItems: [SummaryItem] = [
        SummaryItem(
            content: "The team is finishing prep for the guest room photo shoot.",
            type: .overview,
            sourceSegmentIDs: [sampleTranscriptSegments[0].id, sampleTranscriptSegments[1].id]
        ),
        SummaryItem(
            content: "The photo shoot will move to Thursday morning.",
            type: .decision,
            sourceSegmentIDs: [sampleTranscriptSegments[1].id]
        ),
        SummaryItem(
            content: "Send the revised shot list tonight.",
            type: .actionItem,
            sourceSegmentIDs: [sampleTranscriptSegments[2].id],
            actionStatus: .todo
        ),
        SummaryItem(
            content: "Whether the blue chair stays in the room is still undecided.",
            type: .openQuestion,
            sourceSegmentIDs: [sampleTranscriptSegments[0].id]
        )
    ]

    static let sampleReviewSummary = "The conversation focused on last-minute prep for a guest room photo shoot. The shoot moved to Thursday morning, and the revised shot list was the main follow-up, with one styling choice still open."

    static var sampleRecording: Recording {
        Recording(title: "Shoot Prep", timestamp: previewDate, duration: 39, isPinned: true)
    }

    static var sampleModelContainer: ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container: ModelContainer

        do {
            container = try ModelContainer(for: Recording.self, configurations: configuration)
        } catch {
            fatalError("Failed to create preview model container: \(error.localizedDescription)")
        }

        let context = container.mainContext

        context.insert(Recording(title: "Shoot Prep", timestamp: previewDate, duration: 39, isPinned: true))
        context.insert(Recording(title: "Vendor Follow-up", timestamp: previewDate.addingTimeInterval(-86_400), duration: 24 * 60))
        context.insert(Recording(title: "Neighborhood Interview", timestamp: previewDate.addingTimeInterval(-172_800), duration: 17 * 60))

        do {
            try context.save()
        } catch {
            fatalError("Failed to save preview recordings: \(error.localizedDescription)")
        }

        return container
    }

    static func recordingWithArtifacts() -> Recording {
        let recording = Recording(title: "Shoot Prep", timestamp: previewDate, duration: 39, isPinned: true)
        recording.bookmarks = [6, 28]

        do {
            recording.transcriptFileURL = try StorageService.shared.saveTranscript(sampleTranscriptSegments, uuid: recording.id)
            recording.summaryFileURL = try StorageService.shared.saveReview(
                ReviewArtifact(
                    proseSummary: sampleReviewSummary,
                    summaryItems: sampleSummaryItems
                ),
                uuid: recording.id
            )
        } catch {
            fatalError("Failed to create preview artifacts: \(error.localizedDescription)")
        }

        return recording
    }
}

import Foundation
import Testing
@testable import Rambler

@MainActor
struct SessionDetailViewModelTests {
    @Test
    func loadArtifactsReadsPersistedReviewSummary() throws {
        let recording = Recording(title: "Review Summary Load")
        let summaryItem = SummaryItem(
            content: "Move the vendor walkthrough to Thursday.",
            type: .overview,
            sourceSegmentIDs: [UUID()]
        )

        recording.summaryFileURL = try StorageService.shared.saveReview(
            ReviewArtifact(
                proseSummary: "Finance needs one more pass before the vendor walkthrough.",
                summaryItems: [summaryItem]
            ),
            uuid: recording.id
        )
        defer {
            if let url = recording.summaryFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let viewModel = SessionDetailViewModel(recording: recording)

        #expect(viewModel.normalizedReviewSummary == "Finance needs one more pass before the vendor walkthrough.")
        #expect(viewModel.hasReviewContent)
        #expect(viewModel.summaryItems == [summaryItem])
    }

    @Test
    func saveEditedItemOrdersSummaryItemsByTypeAndSourceOrder() {
        let recording = Recording(title: "Ordering Check")
        defer {
            if let url = recording.summaryFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let first = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            startTime: 0,
            endTime: 8,
            text: "First source",
            isFinal: true
        )
        let second = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            startTime: 8,
            endTime: 16,
            text: "Second source",
            isFinal: true
        )
        let third = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
            startTime: 16,
            endTime: 24,
            text: "Third source",
            isFinal: true
        )

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.segments = [first, second, third]

        let action = SummaryItem(
            content: "Confirm the loading dock window.",
            type: .actionItem,
            sourceSegmentIDs: [second.id],
            actionStatus: .todo,
            isUserEdited: true
        )
        let latePoint = SummaryItem(
            content: "Catering count depends on the final RSVPs.",
            type: .overview,
            sourceSegmentIDs: [third.id],
            isUserEdited: true
        )
        let decision = SummaryItem(
            content: "Use the smaller conference room.",
            type: .decision,
            sourceSegmentIDs: [second.id],
            isUserEdited: true
        )
        let earlyPoint = SummaryItem(
            content: "The guest list still needs a final pass.",
            type: .overview,
            sourceSegmentIDs: [first.id],
            isUserEdited: true
        )

        viewModel.saveEditedItem(action)
        viewModel.saveEditedItem(latePoint)
        viewModel.saveEditedItem(decision)
        viewModel.saveEditedItem(earlyPoint)

        #expect(viewModel.summaryItems.map(\.content) == [
            "The guest list still needs a final pass.",
            "Catering count depends on the final RSVPs.",
            "Use the smaller conference room.",
            "Confirm the loading dock window."
        ])
    }

    @Test
    func sourceEvidenceAndActionProgressReflectCurrentItems() throws {
        let recording = Recording(title: "Evidence Check")
        defer {
            if let url = recording.summaryFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let first = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
            startTime: 12,
            endTime: 20,
            text: "We should keep the landlord walk-through on Tuesday.",
            isFinal: true
        )
        let second = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!,
            startTime: 20,
            endTime: 28,
            text: "I will send the revised lease by Friday.",
            isFinal: true
        )

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.segments = [first, second]

        let action = SummaryItem(
            content: "Send the revised lease by Friday.",
            type: .actionItem,
            sourceSegmentIDs: [second.id],
            actionStatus: .todo,
            isUserEdited: true
        )
        let question = SummaryItem(
            content: "Does the Tuesday walk-through still work for the super?",
            type: .openQuestion,
            sourceSegmentIDs: [first.id, second.id],
            isUserEdited: true
        )

        viewModel.saveEditedItem(action)
        viewModel.saveEditedItem(question)
        viewModel.updateActionStatus(for: action, to: .done)

        let updatedAction = try #require(viewModel.items(for: .actionItem).first)
        let evidence = try #require(viewModel.sourceEvidence(for: question))

        #expect(updatedAction.actionStatus == .done)
        #expect(viewModel.totalActionCount == 1)
        #expect(viewModel.completedActionCount == 1)
        #expect(viewModel.actionProgressLabel == "1 of 1 complete")
        #expect(evidence.timestamp == RamblerFormatters.recordingClock(first.startTime))
        #expect(evidence.additionalSourceCount == 1)
        #expect(evidence.excerpt == first.text)
    }

    @Test
    func saveTranscriptCorrectionPersistsEditedSourceText() async throws {
        let recording = Recording(title: "Transcript Correction")
        let originalSegments = [
            TranscriptSegment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000061")!,
                startTime: 0,
                endTime: 8,
                text: "We should shiop the spring newsletter next week.",
                isFinal: true
            ),
            TranscriptSegment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000062")!,
                startTime: 8,
                endTime: 16,
                text: "I will send the revised subject lines tonight.",
                isFinal: true
            )
        ]

        recording.transcriptFileURL = try StorageService.shared.saveTranscript(originalSegments, uuid: recording.id)
        defer {
            if let url = recording.transcriptFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let viewModel = SessionDetailViewModel(recording: recording)
        let didSave = await viewModel.saveTranscriptCorrection(
            for: originalSegments[0],
            text: "We should ship the spring newsletter next week."
        )

        let persistedSegments = try #require(
            recording.transcriptFileURL.flatMap { StorageService.shared.loadTranscript(from: $0) }
        )

        #expect(didSave)
        #expect(viewModel.segments[0].text == "We should ship the spring newsletter next week.")
        #expect(persistedSegments[0].text == "We should ship the spring newsletter next week.")

        switch viewModel.transcriptUpdateState {
        case .saved(let message):
            #expect(message == "Transcript updated.")
        default:
            Issue.record("Expected a saved transcript state.")
        }
    }

    @Test
    func quickAskRamblerResponseUsesExistingStructuredReviewContent() throws {
        let recording = Recording(title: "Ask Rambler Quick Action")
        let segment = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!,
            startTime: 18,
            endTime: 26,
            text: "I will send the revised lease by Friday.",
            isFinal: true
        )

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.segments = [segment]
        viewModel.saveEditedItem(
            SummaryItem(
                content: "Send the revised lease by Friday.",
                type: .actionItem,
                sourceSegmentIDs: [segment.id],
                actionStatus: .todo,
                isUserEdited: true
            )
        )

        let response = try #require(viewModel.quickAskRamblerResponse(for: .actionList))

        #expect(response.title == "Actions")
        #expect(response.answer.contains("• To Do: Send the revised lease by Friday."))
        #expect(response.sourceSegmentIDs == [segment.id])
        #expect(response.suggestedSaveDestination == .actionItem)
    }

    @Test
    func applyAskRamblerResponseReplacesPersistedReviewSummary() throws {
        let recording = Recording(title: "Ask Rambler Replace Summary")
        defer {
            if let url = recording.summaryFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.reviewSummary = "Old summary."
        viewModel.askRamblerState = .ready(
            AskRamblerResponse(
                title: "Summarize",
                prompt: "Summarize this conversation in a short paragraph.",
                answer: "The vendor walkthrough moved to Thursday morning, and finance still needs to clear the handout.",
                sourceSegmentIDs: [],
                suggestedSaveDestination: .summary
            )
        )

        viewModel.applyAskRamblerResponse(to: .summary)

        #expect(viewModel.normalizedReviewSummary == "The vendor walkthrough moved to Thursday morning, and finance still needs to clear the handout.")
        #expect(viewModel.askRamblerSavedMessage == "Summary updated.")

        let summaryURL = try #require(recording.summaryFileURL)
        let persistedReview = try #require(StorageService.shared.loadReview(from: summaryURL))
        #expect(persistedReview.proseSummary == viewModel.normalizedReviewSummary)
    }

    @Test
    func applyAskRamblerResponseAddsStructuredItemsWithEvidence() throws {
        let recording = Recording(title: "Ask Rambler Save Items")
        defer {
            if let url = recording.summaryFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let segment = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
            startTime: 34,
            endTime: 44,
            text: "I will send the revised invoice, and Maya already filed the permit paperwork.",
            isFinal: true
        )

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.segments = [segment]
        viewModel.askRamblerState = .ready(
            AskRamblerResponse(
                title: "Actions",
                prompt: "What follow-up actions came out of this conversation?",
                answer: "• To Do: Send the revised invoice.\n• Done: File the permit paperwork.",
                sourceSegmentIDs: [segment.id],
                suggestedSaveDestination: .actionItem
            )
        )

        viewModel.applyAskRamblerResponse(to: .actionItem)

        let actions = viewModel.items(for: .actionItem)
        #expect(actions.map(\.content) == ["Send the revised invoice.", "File the permit paperwork."])
        #expect(actions.count == 2)
        #expect(actions[0].actionStatus == .todo)
        #expect(actions[1].actionStatus == .done)
        #expect(actions.allSatisfy { $0.isUserEdited })
        #expect(actions.allSatisfy { $0.sourceSegmentIDs == [segment.id] })
        #expect(viewModel.askRamblerSavedMessage == "Added 2 actions.")
    }

    @Test
    func applyAskRamblerResponseSkipsDuplicateStructuredItems() throws {
        let recording = Recording(title: "Ask Rambler Duplicates")
        defer {
            if let url = recording.summaryFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let segment = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000043")!,
            startTime: 10,
            endTime: 18,
            text: "Please call the caterer before noon.",
            isFinal: true
        )

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.segments = [segment]
        viewModel.saveEditedItem(
            SummaryItem(
                content: "Call the caterer before noon.",
                type: .actionItem,
                sourceSegmentIDs: [segment.id],
                actionStatus: .todo,
                isUserEdited: true
            )
        )
        viewModel.askRamblerState = .ready(
            AskRamblerResponse(
                title: "Actions",
                prompt: "What follow-up actions came out of this conversation?",
                answer: "• To Do: Call the caterer before noon.",
                sourceSegmentIDs: [segment.id],
                suggestedSaveDestination: .actionItem
            )
        )

        viewModel.applyAskRamblerResponse(to: .actionItem)

        #expect(viewModel.items(for: .actionItem).count == 1)
        #expect(viewModel.askRamblerSavedMessage == "That action is already in Review.")
    }

    @Test
    func applyAskRamblerResponseParsesNumberedActionListsAsTodoItems() throws {
        let recording = Recording(title: "Ask Rambler Numbered Actions")
        defer {
            if let url = recording.summaryFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let segment = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000044")!,
            startTime: 22,
            endTime: 34,
            text: "Call the caterer and confirm the chairs before the open house.",
            isFinal: true
        )

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.segments = [segment]
        viewModel.askRamblerState = .ready(
            AskRamblerResponse(
                title: "Actions",
                prompt: "What follow-up actions came out of this conversation?",
                answer: "1. Call the caterer.\n2. Confirm the chairs.",
                sourceSegmentIDs: [segment.id],
                suggestedSaveDestination: .actionItem
            )
        )

        viewModel.applyAskRamblerResponse(to: .actionItem)

        let actions = viewModel.items(for: .actionItem)
        #expect(actions.map(\.content) == ["Call the caterer.", "Confirm the chairs."])
        #expect(actions.allSatisfy { $0.actionStatus == .todo })
    }

    @Test
    func bookmarkStopsUseContainingOrFollowingTranscriptEvidence() throws {
        let recording = Recording(title: "Bookmark Check")
        recording.bookmarks = [4, 18, 40]

        let first = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!,
            startTime: 0,
            endTime: 10,
            text: "Capture the interview notes and keep the transcript central.",
            isFinal: true
        )
        let second = TranscriptSegment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000032")!,
            startTime: 20,
            endTime: 30,
            text: "Send the recap once the hiring debrief is complete.",
            isFinal: true
        )

        let viewModel = SessionDetailViewModel(recording: recording)
        viewModel.segments = [first, second]

        let bookmarkStops = viewModel.bookmarkStops

        #expect(bookmarkStops.map(\.previewText) == [
            first.text,
            second.text,
            second.text
        ])
        #expect(bookmarkStops.map(\.segmentID) == [
            first.id,
            second.id,
            second.id
        ])
        #expect(try #require(bookmarkStops.first).timeLabel == RamblerFormatters.recordingClock(4))
    }
}

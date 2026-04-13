import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class SessionDetailViewModel {
    struct SourceEvidence {
        let timestamp: String
        let accessibilityTimestamp: String
        let excerpt: String
        let additionalSourceCount: Int

        var accessibilityLabel: String {
            let extraSourcesText: String

            switch additionalSourceCount {
            case 0:
                extraSourcesText = ""
            case 1:
                extraSourcesText = " One more source is also linked."
            default:
                extraSourcesText = " \(additionalSourceCount) more sources are also linked."
            }

            return "Source preview at \(accessibilityTimestamp). \(excerpt).\(extraSourcesText)"
        }
    }

    struct BookmarkStop: Identifiable {
        let id: String
        let time: TimeInterval
        let timeLabel: String
        let accessibilityTimeLabel: String
        let previewText: String
        let segmentID: UUID?
    }

    enum TranscriptUpdateState: Equatable {
        case idle
        case saving
        case refreshingReview
        case saved(message: String)
        case failed(message: String)
    }

    var recording: Recording
    var segments: [TranscriptSegment] = []
    var reviewSummary: String?
    var summaryItems: [SummaryItem] = []
    var summaryState: SummaryServiceState = .idle
    var summaryEmptyStateMessage: String?
    var transcriptUpdateState: TranscriptUpdateState = .idle

    let summaryService = SummaryService()
    let playbackService = PlaybackService()
    let logger = Logger(subsystem: "com.WillEdmeades.Rambler", category: "SessionDetail")

    var isPlaying: Bool { playbackService.isPlaying }
    var currentTime: TimeInterval { playbackService.currentTime }

    var selectedTab: String = "Transcript"
    var scrollTargetID: UUID?
    var isEditSheetPresented: Bool = false
    var selectedEditItem: SummaryItem?
    var isExportSheetPresented: Bool = false
    var isAskRamblerSheetPresented: Bool = false
    var askRamblerPrompt: String = ""
    var askRamblerState: AskRamblerState = .idle
    var askRamblerSavedMessage: String?

    var searchText: String = "" {
        didSet { currentSearchIndex = 0 }
    }
    var currentSearchIndex: Int = 0

    init(recording: Recording) {
        self.recording = recording
        summaryService.onStateChange = { [weak self] state in
            self?.summaryState = state
        }
        loadArtifacts()
        if !summaryItems.isEmpty {
            summaryState = .finished(items: summaryItems)
        }
        if let url = recording.audioFileURL {
            playbackService.load(url: url)
        }
    }

    func loadArtifacts() {
        if let url = recording.transcriptFileURL {
            segments = StorageService.shared.loadTranscript(from: url) ?? []
        }
        if let url = recording.summaryFileURL {
            let review = StorageService.shared.loadReview(from: url)
            reviewSummary = review?.normalizedProseSummary
            summaryItems = orderedSummaryItems(review?.summaryItems ?? [])
        }
    }
}

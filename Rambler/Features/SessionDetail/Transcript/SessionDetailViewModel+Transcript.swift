import Foundation
import OSLog

extension SessionDetailViewModel {
    var searchMatches: [UUID] {
        if searchText.isEmpty { return [] }
        return segments.filter { $0.text.localizedCaseInsensitiveContains(searchText) }.map { $0.id }
    }

    var bookmarkStops: [BookmarkStop] {
        recording.bookmarks
            .sorted()
            .map { time in
                let matchedSegment = segment(containingOrFollowing: time)
                return BookmarkStop(
                    id: "\(recording.id.uuidString)-\(time)",
                    time: time,
                    timeLabel: RamblerFormatters.recordingClock(time),
                    accessibilityTimeLabel: RamblerFormatters.accessibilityDuration(time),
                    previewText: matchedSegment?.text ?? "Jump to bookmarked moment.",
                    segmentID: matchedSegment?.id
                )
            }
    }

    func dismissTranscriptUpdateMessage() {
        transcriptUpdateState = .idle
    }

    func saveTranscriptCorrection(for segment: TranscriptSegment, text: String) async -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        TempDebugLog.append("saveTranscriptCorrection start segment=\(segment.id) chars=\(trimmedText.count) hasReview=\(hasReviewContent)")

        guard !trimmedText.isEmpty,
              let index = segments.firstIndex(where: { $0.id == segment.id }) else {
            TempDebugLog.append("saveTranscriptCorrection failed to locate editable segment=\(segment.id)")
            transcriptUpdateState = .failed(message: "The transcript correction couldn’t be saved.")
            return false
        }

        guard segments[index].text != trimmedText else {
            TempDebugLog.append("saveTranscriptCorrection no-op segment=\(segment.id)")
            transcriptUpdateState = .idle
            return true
        }

        let previousSegment = segments[index]
        segments[index].text = trimmedText
        transcriptUpdateState = .saving

        do {
            recording.transcriptFileURL = try StorageService.shared.saveTranscript(segments, uuid: recording.id)
            TempDebugLog.append("saveTranscriptCorrection persisted transcript segment=\(segment.id) url=\(recording.transcriptFileURL?.lastPathComponent ?? "nil")")
        } catch {
            segments[index] = previousSegment
            transcriptUpdateState = .failed(message: "The transcript correction couldn’t be saved.")
            TempDebugLog.append("saveTranscriptCorrection write failed segment=\(segment.id) error=\(error.localizedDescription)")
            logger.error("Failed to persist transcript correction: \(error.localizedDescription, privacy: .public)")
            return false
        }

        guard hasReviewContent else {
            TempDebugLog.append("saveTranscriptCorrection completed without review refresh segment=\(segment.id)")
            transcriptUpdateState = .saved(message: "Transcript updated.")
            return true
        }

        transcriptUpdateState = .refreshingReview
        TempDebugLog.append("saveTranscriptCorrection launched background review refresh segment=\(segment.id)")
        Task {
            await refreshReviewAfterTranscriptCorrection()
        }
        return true
    }

    func togglePlayback() {
        playbackService.togglePlay()
    }

    func seekBackward() {
        playbackService.seek(to: currentTime - 15)
    }

    func seekForward() {
        playbackService.seek(to: currentTime + 15)
    }

    func jumpTo(segment: TranscriptSegment) {
        playbackService.seek(to: segment.startTime)
        scrollTargetID = segment.id
        if !isPlaying {
            playbackService.togglePlay()
        }
    }

    func jumpToSource(of item: SummaryItem) {
        guard let segment = item.sourceSegmentIDs.compactMap({ id in
            segments.first(where: { $0.id == id })
        }).first else { return }

        jumpTo(segment: segment)
    }

    func nextMatch() {
        guard !searchMatches.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchMatches.count
    }

    func previousMatch() {
        guard !searchMatches.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchMatches.count) % searchMatches.count
    }

    func jumpToBookmark(_ bookmark: BookmarkStop) {
        if let segmentID = bookmark.segmentID,
           let segment = segments.first(where: { $0.id == segmentID }) {
            jumpTo(segment: segment)
            return
        }

        playbackService.seek(to: bookmark.time)
        if !isPlaying {
            playbackService.togglePlay()
        }
    }

    func sourceEvidence(for item: SummaryItem) -> SourceEvidence? {
        sourceEvidence(for: item.sourceSegmentIDs)
    }

    func sourceEvidence(for sourceSegmentIDs: [UUID]) -> SourceEvidence? {
        let sourceSegments = sourceSegmentIDs.compactMap { id in
            segments.first(where: { $0.id == id })
        }

        guard let primarySegment = sourceSegments.first else { return nil }

        return SourceEvidence(
            timestamp: RamblerFormatters.recordingClock(primarySegment.startTime),
            accessibilityTimestamp: RamblerFormatters.accessibilityDuration(primarySegment.startTime),
            excerpt: primarySegment.text,
            additionalSourceCount: max(sourceSegments.count - 1, 0)
        )
    }

    func jumpToSourceSegmentIDs(_ sourceSegmentIDs: [UUID]) {
        guard let segment = sourceSegmentIDs.compactMap({ id in
            segments.first(where: { $0.id == id })
        }).first else { return }

        jumpTo(segment: segment)
    }

    private func segment(containingOrFollowing time: TimeInterval) -> TranscriptSegment? {
        if let containingSegment = segments.first(where: { $0.startTime <= time && $0.endTime >= time }) {
            return containingSegment
        }

        return segments.first(where: { $0.startTime >= time }) ?? segments.last
    }

    private func refreshReviewAfterTranscriptCorrection() async {
        let existingSummaryItems = summaryItems
        let existingReviewSummary = reviewSummary
        TempDebugLog.append("refreshReviewAfterTranscriptCorrection started items=\(existingSummaryItems.count) hasSummary=\(existingReviewSummary != nil)")

        await generateSummary()

        switch summaryState {
        case .finished:
            TempDebugLog.append("refreshReviewAfterTranscriptCorrection finished items=\(summaryItems.count)")
            transcriptUpdateState = .saved(message: "Transcript updated. Review updated.")
        case .failed, .unavailable:
            reviewSummary = existingReviewSummary
            summaryItems = existingSummaryItems

            if existingReviewSummary != nil || !existingSummaryItems.isEmpty {
                summaryState = .finished(items: existingSummaryItems)
            }

            TempDebugLog.append("refreshReviewAfterTranscriptCorrection restored previous review state=\(summaryState)")
            transcriptUpdateState = .saved(message: "Transcript updated. Refresh the review again when summaries are available.")
        case .idle, .checkingAvailability, .processing:
            TempDebugLog.append("refreshReviewAfterTranscriptCorrection ended in transitional state=\(summaryState)")
            transcriptUpdateState = .saved(message: "Transcript updated.")
        }
    }
}

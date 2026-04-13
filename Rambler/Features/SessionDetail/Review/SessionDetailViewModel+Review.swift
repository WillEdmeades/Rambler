import Foundation
import OSLog

extension SessionDetailViewModel {
    var normalizedReviewSummary: String? {
        let trimmed = reviewSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    var hasReviewContent: Bool {
        normalizedReviewSummary != nil || !summaryItems.isEmpty
    }

    var totalActionCount: Int {
        items(for: .actionItem).count
    }

    var completedActionCount: Int {
        items(for: .actionItem).filter { $0.actionStatus == .done }.count
    }

    var actionProgressLabel: String {
        if totalActionCount == 0 {
            return "No action items"
        }

        return "\(completedActionCount) of \(totalActionCount) complete"
    }

    func generateSummary() async {
        let previousUserEdits = summaryItems.filter { $0.isUserEdited }
        summaryEmptyStateMessage = nil
        summaryState = .checkingAvailability

        await summaryService.generateRollingSummary(from: segments)

        switch summaryService.state {
        case .finished(let items):
            let combinedItems = orderedSummaryItems(previousUserEdits + items)
            summaryItems = combinedItems
            summaryState = .finished(items: combinedItems)

            if combinedItems.isEmpty {
                reviewSummary = nil
                summaryEmptyStateMessage = segments.isEmpty
                    ? "This session does not have transcript data yet."
                    : "No grounded review items came out of this transcript."
                persistReview()
            } else {
                reviewSummary = await summaryService.generateReviewSummary(
                    from: segments,
                    summaryItems: combinedItems
                )
                persistReview()
            }

        case .idle, .checkingAvailability, .processing:
            summaryState = summaryService.state

        case .unavailable, .failed:
            summaryState = summaryService.state
        }
    }

    func clearSummaryAndRegenerate() {
        let previousUserEdits = summaryItems.filter { $0.isUserEdited }
        reviewSummary = nil
        summaryItems = previousUserEdits
        summaryState = previousUserEdits.isEmpty ? .idle : .finished(items: previousUserEdits)
        summaryEmptyStateMessage = nil
        persistReview()
        Task { await generateSummary() }
    }

    func saveEditedItem(_ item: SummaryItem) {
        if let index = summaryItems.firstIndex(where: { $0.id == item.id }) {
            summaryItems[index] = item
        } else {
            summaryItems.append(item)
        }
        summaryItems = orderedSummaryItems(summaryItems)
        persistReview()
    }

    func deleteSummaryItem(_ item: SummaryItem) {
        summaryItems.removeAll { $0.id == item.id }
        persistReview()
    }

    func updateActionStatus(for item: SummaryItem, to status: SummaryItem.ActionStatus) {
        if let index = summaryItems.firstIndex(where: { $0.id == item.id }) {
            summaryItems[index].actionStatus = status
            summaryItems[index].isUserEdited = true
            summaryItems = orderedSummaryItems(summaryItems)
            persistReview()
        }
    }

    func beginEditing(_ item: SummaryItem) {
        selectedEditItem = item
        isEditSheetPresented = true
    }

    func beginCreatingItem(of type: SummaryItem.ItemType) {
        selectedEditItem = SummaryItem(content: "", type: type, isUserEdited: true)
        isEditSheetPresented = true
    }

    func presentAskRambler() {
        askRamblerPrompt = ""
        askRamblerState = .idle
        askRamblerSavedMessage = nil
        isAskRamblerSheetPresented = true
    }

    func resetAskRambler() {
        askRamblerPrompt = ""
        askRamblerState = .idle
        askRamblerSavedMessage = nil
    }

    func runAskRambler(action: AskRamblerQuickAction? = nil) async {
        let prompt: String
        let title: String

        if let action {
            prompt = action.defaultPrompt
            title = action.title
            askRamblerPrompt = prompt

            if let quickResponse = quickAskRamblerResponse(for: action) {
                askRamblerSavedMessage = nil
                askRamblerState = .ready(quickResponse)
                return
            }
        } else {
            prompt = askRamblerPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            title = "Answer"

            guard !prompt.isEmpty else {
                askRamblerState = .failed(message: "Ask a focused question before sending it to Rambler.")
                return
            }
        }

        askRamblerSavedMessage = nil
        askRamblerState = .generating(title: title)

        let result = await summaryService.askRambler(
            question: prompt,
            title: title,
            reviewSummary: normalizedReviewSummary,
            summaryItems: summaryItems,
            segments: segments
        )

        switch result {
        case .success(let response):
            askRamblerState = .ready(
                AskRamblerResponse(
                    title: response.title,
                    prompt: response.prompt,
                    answer: response.answer,
                    sourceSegmentIDs: response.sourceSegmentIDs,
                    suggestedSaveDestination: action?.suggestedSaveDestination
                )
            )
        case .failure(let error):
            askRamblerState = .failed(message: error.localizedDescription)
        }
    }

    func quickAskRamblerResponse(for action: AskRamblerQuickAction) -> AskRamblerResponse? {
        switch action {
        case .summarize:
            guard let answer = normalizedReviewSummary ?? fallbackQuickSummary() else { return nil }
            return AskRamblerResponse(
                title: action.title,
                prompt: action.defaultPrompt,
                answer: answer,
                sourceSegmentIDs: quickActionSourceSegmentIDs(from: summaryItems),
                suggestedSaveDestination: action.suggestedSaveDestination
            )

        case .keyPoints, .decisions, .actionList, .openQuestions:
            guard let itemType = action.itemType else { return nil }
            let items = items(for: itemType)
            guard !items.isEmpty else { return nil }

            return AskRamblerResponse(
                title: action.title,
                prompt: action.defaultPrompt,
                answer: quickActionAnswer(from: items),
                sourceSegmentIDs: quickActionSourceSegmentIDs(from: items),
                suggestedSaveDestination: action.suggestedSaveDestination
            )
        }
    }

    func applyAskRamblerResponse(to destination: AskRamblerSaveDestination) {
        guard case .ready(let response) = askRamblerState else { return }

        switch destination {
        case .summary:
            let normalizedAnswer = response.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedAnswer.isEmpty else {
                askRamblerSavedMessage = "Nothing to save."
                return
            }

            if normalizedReviewSummary == normalizedAnswer {
                askRamblerSavedMessage = destination.duplicateMessage()
                return
            }

            reviewSummary = normalizedAnswer
            persistReview()
            askRamblerSavedMessage = destination.successMessage(savedCount: 1)

        case .keyPoint, .decision, .actionItem, .openQuestion:
            guard let itemType = destination.itemType else { return }
            let newItems = makeAskRamblerItems(
                from: response.answer,
                type: itemType,
                sourceSegmentIDs: response.sourceSegmentIDs
            )

            guard !newItems.isEmpty else {
                askRamblerSavedMessage = "Nothing to save."
                return
            }

            let existingKeys = Set(summaryItems.map(reviewItemDeduplicationKey(for:)))
            let uniqueItems = newItems.filter { !existingKeys.contains(reviewItemDeduplicationKey(for: $0)) }

            guard !uniqueItems.isEmpty else {
                askRamblerSavedMessage = destination.duplicateMessage()
                return
            }

            summaryItems = orderedSummaryItems(summaryItems + uniqueItems)
            persistReview()
            askRamblerSavedMessage = destination.successMessage(savedCount: uniqueItems.count)
        }
    }

    func items(for type: SummaryItem.ItemType) -> [SummaryItem] {
        summaryItems.filter { $0.type == type }
    }

    func orderedSummaryItems(_ items: [SummaryItem]) -> [SummaryItem] {
        let segmentOrder = Dictionary(uniqueKeysWithValues: segments.enumerated().map { ($1.id, $0) })
        let typeOrder: [SummaryItem.ItemType: Int] = [
            .overview: 0,
            .decision: 1,
            .actionItem: 2,
            .openQuestion: 3
        ]

        return items.sorted { lhs, rhs in
            let lhsTypeOrder = typeOrder[lhs.type, default: .max]
            let rhsTypeOrder = typeOrder[rhs.type, default: .max]

            if lhsTypeOrder != rhsTypeOrder {
                return lhsTypeOrder < rhsTypeOrder
            }

            let lhsSourceOrder = lhs.sourceSegmentIDs.compactMap { segmentOrder[$0] }.min() ?? .max
            let rhsSourceOrder = rhs.sourceSegmentIDs.compactMap { segmentOrder[$0] }.min() ?? .max

            if lhsSourceOrder != rhsSourceOrder {
                return lhsSourceOrder < rhsSourceOrder
            }

            return lhs.content.localizedCaseInsensitiveCompare(rhs.content) == .orderedAscending
        }
    }

    func persistReview() {
        let review = ReviewArtifact(
            proseSummary: normalizedReviewSummary,
            summaryItems: summaryItems
        )

        if review.isEmpty {
            clearPersistedReview()
            return
        }

        do {
            recording.summaryFileURL = try StorageService.shared.saveReview(review, uuid: recording.id)
        } catch {
            logger.error("Failed to persist review: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearPersistedReview() {
        guard let url = recording.summaryFileURL else { return }

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            recording.summaryFileURL = nil
        } catch {
            logger.error("Failed to clear review artifact: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func quickActionAnswer(from items: [SummaryItem]) -> String {
        items.prefix(5)
            .map { item in
                if item.type == .actionItem, let status = item.actionStatus {
                    return "• \(status.rawValue): \(item.content)"
                }

                return "• \(item.content)"
            }
            .joined(separator: "\n")
    }

    private func quickActionSourceSegmentIDs(from items: [SummaryItem]) -> [UUID] {
        let sourceIDs = items.flatMap(\.sourceSegmentIDs)
        if !sourceIDs.isEmpty {
            return Array(NSOrderedSet(array: sourceIDs).compactMap { $0 as? UUID }.prefix(3))
        }

        return Array(segments.prefix(1).map(\.id))
    }

    private func fallbackQuickSummary() -> String? {
        let candidateSentences = summaryItems.map(\.content).prefix(2)
        guard !candidateSentences.isEmpty else { return nil }

        return candidateSentences
            .map { sentence in
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let terminal = trimmed.unicodeScalars.last else { return trimmed }
                if CharacterSet(charactersIn: ".!?").contains(terminal) {
                    return trimmed
                }
                return trimmed + "."
            }
            .joined(separator: " ")
    }

    private func makeAskRamblerItems(
        from answer: String,
        type: SummaryItem.ItemType,
        sourceSegmentIDs: [UUID]
    ) -> [SummaryItem] {
        let candidateLines = normalizedAskRamblerLines(from: answer)

        return candidateLines.compactMap { line in
            let normalizedContent = normalizedAskRamblerContent(from: line)
            guard !normalizedContent.isEmpty else { return nil }

            if type == .actionItem {
                let parsedAction = parseAskRamblerActionLine(normalizedContent)
                return SummaryItem(
                    content: parsedAction.content,
                    type: type,
                    sourceSegmentIDs: sourceSegmentIDs,
                    actionStatus: parsedAction.status,
                    isUserEdited: true
                )
            }

            return SummaryItem(
                content: normalizedContent,
                type: type,
                sourceSegmentIDs: sourceSegmentIDs,
                isUserEdited: true
            )
        }
    }

    private func normalizedAskRamblerLines(from answer: String) -> [String] {
        let lines = answer
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count > 1 {
            return lines
        }

        let flattened = answer
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened.isEmpty ? [] : [flattened]
    }

    private func normalizedAskRamblerContent(from line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)

        let bulletPrefixes = ["•", "-", "*", "–", "—"]
        for prefix in bulletPrefixes where cleaned.hasPrefix(prefix) {
            cleaned.removeFirst(prefix.count)
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        if let range = cleaned.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseAskRamblerActionLine(_ line: String) -> (content: String, status: SummaryItem.ActionStatus) {
        for status in SummaryItem.ActionStatus.allCases {
            let prefix = "\(status.rawValue):"
            if line.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil {
                let content = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                return (content.isEmpty ? line : content, status)
            }
        }

        return (line, .todo)
    }

    private func reviewItemDeduplicationKey(for item: SummaryItem) -> String {
        "\(item.type.rawValue)|\(item.content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}

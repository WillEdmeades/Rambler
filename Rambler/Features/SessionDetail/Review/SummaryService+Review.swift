import Foundation

extension SummaryService {
    func generateReviewSummary(from segments: [TranscriptSegment], summaryItems: [SummaryItem]) async -> String? {
        guard !segments.isEmpty || !summaryItems.isEmpty else { return nil }

        let structuredItems = summaryItems.prefix(6).map {
            "\($0.type.rawValue): \($0.content)"
        }
        let structuredItemsBlock = structuredItems.isEmpty ? "None" : structuredItems.joined(separator: "\n")

        let evidenceLines = summaryItems.prefix(4).compactMap { item -> String? in
            guard let sourceID = item.sourceSegmentIDs.first,
                  let segment = segments.first(where: { $0.id == sourceID }) else {
                return nil
            }

            return "[\(RamblerFormatters.recordingClock(segment.startTime))] \(segment.text)"
        }

        let transcriptFallback = segments.prefix(4).map {
            "[\(RamblerFormatters.recordingClock($0.startTime))] \($0.text)"
        }
        let evidenceBlockSource = evidenceLines.isEmpty ? transcriptFallback : evidenceLines
        let evidenceBlock = evidenceBlockSource.isEmpty ? "None" : evidenceBlockSource.joined(separator: "\n")

        let instructions = """
        Write a short prose summary for a conversation review screen.
        Stay grounded in the transcript and the accepted review items.
        Write one short paragraph in plain English.
        Keep it to two or three concise sentences.
        Mention decisions or next steps only when they are explicit.
        Do not use bullets, speaker names, timestamps, or UUIDs.
        """

        let prompt = """
        Create a short review summary for this conversation.

        Structured review items:
        \(structuredItemsBlock)

        Supporting transcript lines:
        \(evidenceBlock)
        """

        do {
            let response = try await languageModel.generateText(
                prompt: prompt,
                instructions: instructions
            )

            if let normalized = normalizedReviewSummary(response) {
                return normalized
            }
        } catch {
            return fallbackReviewSummary(from: summaryItems, segments: segments)
        }

        return fallbackReviewSummary(from: summaryItems, segments: segments)
    }

    func askRambler(
        question: String,
        title: String,
        reviewSummary: String?,
        summaryItems: [SummaryItem],
        segments: [TranscriptSegment]
    ) async -> Result<AskRamblerResponse, AskRamblerError> {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            return .failure(AskRamblerError(message: "Ask a focused question before sending it to Rambler."))
        }

        guard !segments.isEmpty || !summaryItems.isEmpty || normalizedReviewSummary(reviewSummary) != nil else {
            return .failure(AskRamblerError(message: "There isn’t enough session content yet to answer that."))
        }

        let availability = await languageModel.isAvailable()
        guard availability.0 else {
            return .failure(AskRamblerError(message: availability.1))
        }

        let prompt = buildAskRamblerPrompt(
            question: trimmedQuestion,
            reviewSummary: reviewSummary,
            summaryItems: summaryItems,
            segments: segments
        )

        let instructions = """
        Answer focused questions about a captured conversation.
        Stay grounded in the transcript and accepted review items.
        Keep the answer concise and useful.
        If the user asks for a list, use short dash bullets.
        If the transcript does not establish the answer, say so plainly.
        Do not invent speakers, intent, ownership, or decisions.
        """

        do {
            let response = try await languageModel.generateText(
                prompt: prompt,
                instructions: instructions
            )

            guard let answer = normalizedGeneratedAnswer(response) else {
                return .failure(AskRamblerError(message: "Rambler couldn’t produce a grounded answer for that prompt."))
            }

            return .success(
                AskRamblerResponse(
                    title: title,
                    prompt: trimmedQuestion,
                    answer: answer,
                    sourceSegmentIDs: matchedSourceSegmentIDs(
                        for: trimmedQuestion + "\n" + answer,
                        summaryItems: summaryItems,
                        segments: segments
                    ),
                    suggestedSaveDestination: nil
                )
            )
        } catch {
            return .failure(AskRamblerError(message: error.localizedDescription))
        }
    }

    private func normalizedReviewSummary(_ text: String?) -> String? {
        let trimmed = text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-• \n\t"))

        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func fallbackReviewSummary(from summaryItems: [SummaryItem], segments: [TranscriptSegment]) -> String? {
        let candidateSentences = summaryItems.map(\.content) + segments.prefix(2).map(\.text)
        let normalizedSentences = candidateSentences.compactMap(normalizedSentence)

        guard !normalizedSentences.isEmpty else { return nil }
        return normalizedSentences.prefix(2).joined(separator: " ")
    }

    private func normalizedSentence(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let terminalPunctuation = CharacterSet(charactersIn: ".!?")
        if let unicodeScalar = trimmed.unicodeScalars.last,
           terminalPunctuation.contains(unicodeScalar) {
            return trimmed
        }

        return trimmed + "."
    }

    private func buildAskRamblerPrompt(
        question: String,
        reviewSummary: String?,
        summaryItems: [SummaryItem],
        segments: [TranscriptSegment]
    ) -> String {
        let reviewSummaryBlock = normalizedReviewSummary(reviewSummary) ?? "None"

        let structuredItemsBlock: String
        if summaryItems.isEmpty {
            structuredItemsBlock = "None"
        } else {
            structuredItemsBlock = summaryItems
                .prefix(10)
                .map { "\($0.type.rawValue): \($0.content)" }
                .joined(separator: "\n")
        }

        let transcriptBlock: String
        if segments.isEmpty {
            transcriptBlock = "None"
        } else {
            transcriptBlock = segments
                .prefix(24)
                .map { "[\($0.id.uuidString)] \($0.text)" }
                .joined(separator: "\n")
        }

        return """
        Existing review summary:
        \(reviewSummaryBlock)

        Accepted review items:
        \(structuredItemsBlock)

        Transcript excerpts:
        \(transcriptBlock)

        User question:
        \(question)
        """
    }

    private func normalizedGeneratedAnswer(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func matchedSourceSegmentIDs(
        for text: String,
        summaryItems: [SummaryItem],
        segments: [TranscriptSegment]
    ) -> [UUID] {
        let queryTokens = tokenSet(from: text)
        guard !segments.isEmpty else { return [] }

        var scoredCandidates: [(UUID, Int)] = []
        var seen = Set<UUID>()

        for item in summaryItems {
            let overlap = overlapScore(queryTokens, tokenSet(from: item.content))
            guard overlap > 0 else { continue }

            for sourceID in item.sourceSegmentIDs where seen.insert(sourceID).inserted {
                scoredCandidates.append((sourceID, overlap + 2))
            }
        }

        for segment in segments {
            let overlap = overlapScore(queryTokens, tokenSet(from: segment.text))
            guard overlap > 0, seen.insert(segment.id).inserted else { continue }
            scoredCandidates.append((segment.id, overlap))
        }

        let sorted = scoredCandidates
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }

                let lhsIndex = segments.firstIndex(where: { $0.id == lhs.0 }) ?? .max
                let rhsIndex = segments.firstIndex(where: { $0.id == rhs.0 }) ?? .max
                return lhsIndex < rhsIndex
            }
            .map(\.0)

        if !sorted.isEmpty {
            return Array(sorted.prefix(3))
        }

        let fallbackFromSummaryItems = Array(summaryItems.flatMap(\.sourceSegmentIDs).prefix(3))
        if !fallbackFromSummaryItems.isEmpty {
            return fallbackFromSummaryItems
        }

        return Array(segments.prefix(1).map(\.id))
    }

    private func tokenSet(from text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "about", "after", "also", "been", "from", "into", "just", "more",
            "that", "than", "them", "they", "this", "what", "when", "where",
            "which", "with", "would", "your"
        ]

        return Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stopWords.contains($0) }
        )
    }

    private func overlapScore(_ lhs: Set<String>, _ rhs: Set<String>) -> Int {
        lhs.intersection(rhs).count
    }
}

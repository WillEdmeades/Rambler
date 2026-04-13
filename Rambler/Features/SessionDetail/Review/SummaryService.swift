import Foundation
import FoundationModels
import Observation

private struct SummaryItemConversion {
    var items: [SummaryItem]
    var discardedCount: Int
}

// MARK: - Language Model Protocol

@MainActor
protocol LanguageModelProvider {
    func isAvailable() async -> (Bool, String)

    func generate<Content: Generable & Sendable>(
        prompt: String,
        instructions: String,
        generating type: Content.Type
    ) async throws -> Content

    func generateText(
        prompt: String,
        instructions: String
    ) async throws -> String
}

@MainActor
final class NativeLanguageModelWrapper: LanguageModelProvider {
    func isAvailable() async -> (Bool, String) {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            return (true, "On-device Foundation Models are available.")
        case .unavailable(let reason):
            return (false, "On-device Foundation Models are unavailable: \(reason).")
        }
    }

    func generate<Content: Generable & Sendable>(
        prompt: String,
        instructions: String,
        generating type: Content.Type
    ) async throws -> Content {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: prompt,
            generating: type,
            includeSchemaInPrompt: false
        )
        return response.content
    }

    func generateText(
        prompt: String,
        instructions: String
    ) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

// MARK: - Guided Generation Types

@Generable
private struct GuidedInsight: Sendable {
    @Guide(description: "Exact UUID string of the transcript segment that directly supports this summary item.")
    var sourceID: String

    @Guide(description: "Short, plain-English label for the idea.")
    var topic: String

    @Guide(description: "One concise sentence grounded directly in the transcript.")
    var details: String

    func toSummaryItem(type: SummaryItem.ItemType, validSourceIDs: Set<UUID>) -> SummaryItem? {
        guard let sourceSegmentID = resolvedSourceID(validSourceIDs: validSourceIDs) else { return nil }

        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let content: String

        if trimmedTopic.isEmpty {
            content = trimmedDetails
        } else if trimmedDetails.isEmpty {
            content = trimmedTopic
        } else {
            content = "\(trimmedTopic): \(trimmedDetails)"
        }

        guard !content.isEmpty else { return nil }

        return SummaryItem(
            content: content,
            type: type,
            sourceSegmentIDs: [sourceSegmentID]
        )
    }

    private func resolvedSourceID(validSourceIDs: Set<UUID>) -> UUID? {
        extractedUUIDCandidates().first(where: validSourceIDs.contains)
    }

    private func extractedUUIDCandidates() -> [UUID] {
        var orderedCandidates: [UUID] = []
        var seen = Set<UUID>()

        let directCandidates = [
            sourceID.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceID.trimmingCharacters(in: CharacterSet(charactersIn: "[](){}<>.,;: \n\t"))
        ]

        for candidate in directCandidates {
            guard let uuid = UUID(uuidString: candidate), seen.insert(uuid).inserted else { continue }
            orderedCandidates.append(uuid)
        }

        let pattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return orderedCandidates
        }

        let rawSourceID = sourceID as NSString
        let matches = regex.matches(
            in: sourceID,
            range: NSRange(location: 0, length: rawSourceID.length)
        )

        for match in matches {
            let candidate = rawSourceID.substring(with: match.range)
            guard let uuid = UUID(uuidString: candidate), seen.insert(uuid).inserted else { continue }
            orderedCandidates.append(uuid)
        }

        return orderedCandidates
    }
}

@Generable
private struct GuidedSummaryDelta: Sendable {
    @Guide(description: "Key points or main takeaways discussed in this chunk.")
    var overviewPoints: [GuidedInsight]

    @Guide(description: "Concrete decisions, agreements, or conclusions reached in this chunk.")
    var decisions: [GuidedInsight]

    @Guide(description: "Concrete follow-up tasks assigned or volunteered in this chunk.")
    var actionItems: [GuidedInsight]

    @Guide(description: "Open issues or unresolved questions still needing an answer.")
    var openQuestions: [GuidedInsight]

    func toSummaryItems(validSourceIDs: Set<UUID>) -> SummaryItemConversion {
        var items: [SummaryItem] = []
        var discardedCount = 0

        for insight in overviewPoints {
            if let item = insight.toSummaryItem(type: .overview, validSourceIDs: validSourceIDs) {
                items.append(item)
            } else {
                discardedCount += 1
            }
        }

        for insight in decisions {
            if let item = insight.toSummaryItem(type: .decision, validSourceIDs: validSourceIDs) {
                items.append(item)
            } else {
                discardedCount += 1
            }
        }

        for insight in actionItems {
            if let item = insight.toSummaryItem(type: .actionItem, validSourceIDs: validSourceIDs) {
                items.append(item)
            } else {
                discardedCount += 1
            }
        }

        for insight in openQuestions {
            if let item = insight.toSummaryItem(type: .openQuestion, validSourceIDs: validSourceIDs) {
                items.append(item)
            } else {
                discardedCount += 1
            }
        }

        return SummaryItemConversion(items: items, discardedCount: discardedCount)
    }
}

// MARK: - State

enum SummaryServiceState: Equatable {
    case idle
    case checkingAvailability
    case unavailable(reason: String)
    case processing(chunk: Int, total: Int)
    case finished(items: [SummaryItem])
    case failed(error: String)
}

// MARK: - Service

@Observable
@MainActor
final class SummaryService {
    struct AskRamblerError: LocalizedError, Sendable {
        let message: String

        var errorDescription: String? { message }
    }

    var state: SummaryServiceState = .idle

    @ObservationIgnored var onStateChange: ((SummaryServiceState) -> Void)?

    let chunker: TranscriptChunker
    let languageModel: LanguageModelProvider

    init(chunker: TranscriptChunker? = nil, languageModel: LanguageModelProvider? = nil) {
        self.chunker = chunker ?? TranscriptChunker()
        self.languageModel = languageModel ?? NativeLanguageModelWrapper()
    }

    func generateRollingSummary(from segments: [TranscriptSegment]) async {
        updateState(.checkingAvailability)

        let availability = await languageModel.isAvailable()
        guard availability.0 else {
            updateState(.unavailable(reason: availability.1))
            return
        }

        let chunks = chunker.generateChunks(from: segments)
        guard !chunks.isEmpty else {
            updateState(.finished(items: []))
            return
        }

        var rollingItems: [SummaryItem] = []
        var discardedItemCount = 0
        let instructions = summaryInstructions

        for (index, chunk) in chunks.enumerated() {
            updateState(.processing(chunk: index + 1, total: chunks.count))

            do {
                let delta = try await languageModel.generate(
                    prompt: buildPrompt(chunk: chunk, previousContext: rollingItems),
                    instructions: instructions,
                    generating: GuidedSummaryDelta.self
                )
                let conversion = delta.toSummaryItems(validSourceIDs: Set(chunk.segments.map(\.id)))
                discardedItemCount += conversion.discardedCount
                rollingItems = deduplicatedSummaryItems(from: rollingItems + conversion.items)
            } catch {
                updateState(.failed(error: error.localizedDescription))
                return
            }
        }

        if rollingItems.isEmpty, discardedItemCount > 0 {
            updateState(.failed(error: "The model returned summary items, but their source links were invalid."))
            return
        }

        if rollingItems.isEmpty {
            if let fallbackItem = await generateFallbackOverview(from: segments) {
                rollingItems = [fallbackItem]
            }
        }

        updateState(.finished(items: rollingItems))
    }

    private var summaryInstructions: String {
        """
        You summarize deliberate conversations for Rambler, an iPhone-first notes app.
        Always stay grounded in the transcript.
        Only extract items that are directly supported by the provided transcript lines.
        Never invent participants, decisions, tasks, or unresolved questions.
        Keep every item concise, readable, and useful in a clean notes UI.
        Preserve source evidence by copying the exact transcript UUID into sourceID.
        Prefer concrete key points over vague recaps.
        Decisions should clearly state what was decided or committed.
        Action items should read like checklist items and start with a verb when the transcript supports it.
        Do not invent owners, deadlines, or intent that are not explicit in the transcript.
        If the transcript contains meaningful discussion, produce at least one key point.
        Return all arrays empty only when the transcript truly contains no meaningful discussion.
        If a category has no grounded items, return an empty array for that category.
        """
    }

    private func buildPrompt(chunk: TranscriptChunk, previousContext: [SummaryItem]) -> String {
        let transcriptBlock = chunk.segments
            .map { "[\($0.id.uuidString)] \($0.text)" }
            .joined(separator: "\n")

        let previousContextBlock: String
        if previousContext.isEmpty {
            previousContextBlock = "None"
        } else {
            previousContextBlock = previousContext
                .map { "\($0.type.rawValue): \($0.content)" }
                .joined(separator: "\n")
        }

        return """
        Earlier accepted summary items:
        \(previousContextBlock)

        Analyze the transcript chunk below and extract only new grounded items that add value beyond the earlier accepted summary items.

        Rules:
        - Use only the bare UUID string from the transcript line as sourceID.
        - Do not duplicate an earlier accepted item unless the new chunk adds materially different information.
        - Overview points should read like short key points someone can scan after the conversation.
        - Decisions must reflect an agreement, conclusion, or committed direction.
        - Action items must reflect a concrete follow-up task and should read naturally in a checklist.
        - Open questions must remain unresolved in the transcript.
        - Prefer one sourceID per item, choosing the strongest supporting line.

        Transcript chunk:
        \(transcriptBlock)
        """
    }

    private func deduplicatedSummaryItems(from items: [SummaryItem]) -> [SummaryItem] {
        var seenKeys = Set<String>()
        var deduplicated: [SummaryItem] = []

        for item in items {
            let sourceKey = item.sourceSegmentIDs.map(\.uuidString).joined(separator: ",")
            let contentKey = item.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let key = "\(item.type.rawValue)|\(sourceKey)|\(contentKey)"

            if seenKeys.insert(key).inserted {
                deduplicated.append(item)
            }
        }

        return deduplicated
    }

    private func generateFallbackOverview(from segments: [TranscriptSegment]) async -> SummaryItem? {
        guard !segments.isEmpty else { return nil }

        let strongestSegment = segments.max { lhs, rhs in
            lhs.text.count < rhs.text.count
        }

        guard let strongestSegment else { return nil }

        let transcriptBlock = segments
            .map { "[\($0.id.uuidString)] \($0.text)" }
            .joined(separator: "\n")

        let instructions = """
        You create one concise, transcript-grounded key point for Rambler.
        Use only information that appears in the transcript.
        Do not invent facts, speakers, decisions, or action items.
        Produce a concise sentence suitable for a clean notes interface.
        """

        let prompt = """
        Write one concise key point for this conversation.
        The sentence must summarize the main topic or outcome in plain English.
        Do not mention UUIDs or formatting markers.

        Transcript:
        \(transcriptBlock)
        """

        do {
            let response = try await languageModel.generateText(
                prompt: prompt,
                instructions: instructions
            )

            let content = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-• \n\t"))

            guard !content.isEmpty else { return nil }

            return SummaryItem(
                content: content,
                type: .overview,
                sourceSegmentIDs: [strongestSegment.id]
            )
        } catch {
            return nil
        }
    }

    private func updateState(_ newState: SummaryServiceState) {
        state = newState
        onStateChange?(newState)
    }
}

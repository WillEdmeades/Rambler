import Foundation

enum ExportTextScope {
    case fullSession
    case summaryNotes
    case actionsOnly

    var filenameSuffix: String {
        switch self {
        case .fullSession:
            return ""
        case .summaryNotes:
            return " Summary"
        case .actionsOnly:
            return " Actions"
        }
    }
}

enum ExportServiceError: LocalizedError {
    case failedToWriteFile(Error)
    case failedToCopyAudio(Error)
    case failedToEncodeJSON(Error)

    var errorDescription: String? {
        switch self {
        case .failedToWriteFile(let error):
            return "The export file couldn't be written. \(error.localizedDescription)"
        case .failedToCopyAudio(let error):
            return "The audio file couldn't be prepared for export. \(error.localizedDescription)"
        case .failedToEncodeJSON(let error):
            return "The JSON export couldn't be created. \(error.localizedDescription)"
        }
    }
}

final class ExportService {
    static let shared = ExportService()

    private init() {}

    func generateMarkdown(
        for recording: Recording,
        segments: [TranscriptSegment],
        reviewSummary: String? = nil,
        summaries: [SummaryItem],
        scope: ExportTextScope = .fullSession
    ) throws -> URL {
        let markdown = buildMarkdownContent(
            for: recording,
            segments: segments,
            reviewSummary: reviewSummary,
            summaries: summaries,
            scope: scope
        )
        let url = temporaryURL(for: recording.title, pathExtension: "md", scope: scope)

        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportServiceError.failedToWriteFile(error)
        }

        return url
    }

    func generatePlainText(
        for recording: Recording,
        segments: [TranscriptSegment],
        reviewSummary: String? = nil,
        summaries: [SummaryItem],
        scope: ExportTextScope = .fullSession
    ) throws -> URL {
        let text = buildPlainTextContent(
            for: recording,
            segments: segments,
            reviewSummary: reviewSummary,
            summaries: summaries,
            scope: scope
        )
        let url = temporaryURL(for: recording.title, pathExtension: "txt", scope: scope)

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportServiceError.failedToWriteFile(error)
        }

        return url
    }

    func duplicateAudio(from url: URL, title: String) throws -> URL {
        let tempURL = temporaryURL(for: title, pathExtension: "m4a")

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            throw ExportServiceError.failedToCopyAudio(error)
        }

        return tempURL
    }

    func generateJSON(
        for recording: Recording,
        segments: [TranscriptSegment],
        reviewSummary: String? = nil,
        summaries: [SummaryItem]
    ) throws -> URL {
        struct ExportWrapper: Codable {
            let metadata: RecordingMetadata
            let reviewSummary: String?
            let summaryItems: [SummaryItem]
            let transcript: [TranscriptSegment]
        }

        struct RecordingMetadata: Codable {
            let id: UUID
            let title: String
            let date: Date
            let duration: TimeInterval
        }

        let wrapper = ExportWrapper(
            metadata: RecordingMetadata(
                id: recording.id,
                title: recording.title,
                date: recording.timestamp,
                duration: recording.duration
            ),
            reviewSummary: normalizedReviewSummary(reviewSummary),
            summaryItems: summaries,
            transcript: segments
        )

        let url = temporaryURL(for: recording.title, pathExtension: "json", scope: .fullSession)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(wrapper)
            try data.write(to: url)
        } catch {
            if error is EncodingError {
                throw ExportServiceError.failedToEncodeJSON(error)
            }

            throw ExportServiceError.failedToWriteFile(error)
        }

        return url
    }

    func generateFullPackage(
        recording: Recording,
        segments: [TranscriptSegment],
        reviewSummary: String? = nil,
        summaries: [SummaryItem]
    ) throws -> [URL] {
        var urls = [try generateMarkdown(
            for: recording,
            segments: segments,
            reviewSummary: reviewSummary,
            summaries: summaries
        )]

        if let audio = recording.audioFileURL {
            urls.append(try duplicateAudio(from: audio, title: recording.title))
        }

        urls.append(try generateJSON(
            for: recording,
            segments: segments,
            reviewSummary: reviewSummary,
            summaries: summaries
        ))
        return urls
    }

    private func temporaryURL(for title: String, pathExtension: String) -> URL {
        temporaryURL(for: title, pathExtension: pathExtension, scope: .fullSession)
    }

    private func temporaryURL(for title: String, pathExtension: String, scope: ExportTextScope) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitizedFilenameStem(for: title) + scope.filenameSuffix)
            .appendingPathExtension(pathExtension)
    }

    private func sanitizedFilenameStem(for title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let sanitized = title
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "Rambler Export" : sanitized
    }

    private func buildMarkdownContent(
        for recording: Recording,
        segments: [TranscriptSegment],
        reviewSummary: String?,
        summaries: [SummaryItem],
        scope: ExportTextScope
    ) -> String {
        var markdown = "# \(recording.title)\n\n"
        markdown += "**Date:** \(recording.timestamp.formatted())\n"
        markdown += "**Duration:** \(RamblerFormatters.recordingClock(recording.duration))\n\n---\n\n"

        appendReviewSummary(
            to: &markdown,
            reviewSummary: reviewSummary,
            markdownStyle: true,
            scope: scope
        )
        appendSummarySections(
            to: &markdown,
            reviewSummary: reviewSummary,
            summaries: filteredSummaries(for: scope, from: summaries),
            markdownStyle: true,
            scope: scope
        )

        if scope == .fullSession, !segments.isEmpty {
            markdown += "## Transcript\n"
            for segment in segments {
                markdown += "[\(RamblerFormatters.recordingClock(segment.startTime))] \(segment.text)\n\n"
            }
        }

        return markdown
    }

    private func buildPlainTextContent(
        for recording: Recording,
        segments: [TranscriptSegment],
        reviewSummary: String?,
        summaries: [SummaryItem],
        scope: ExportTextScope
    ) -> String {
        var text = "\(recording.title)\n\n"
        text += "Date: \(recording.timestamp.formatted())\n"
        text += "Duration: \(RamblerFormatters.recordingClock(recording.duration))\n\n"

        appendReviewSummary(
            to: &text,
            reviewSummary: reviewSummary,
            markdownStyle: false,
            scope: scope
        )
        appendSummarySections(
            to: &text,
            reviewSummary: reviewSummary,
            summaries: filteredSummaries(for: scope, from: summaries),
            markdownStyle: false,
            scope: scope
        )

        if scope == .fullSession, !segments.isEmpty {
            text += "Transcript\n"
            text += "----------\n"

            for segment in segments {
                text += "[\(RamblerFormatters.recordingClock(segment.startTime))] \(segment.text)\n"
            }
        }

        return text
    }

    private func appendSummarySections(
        to output: inout String,
        reviewSummary: String?,
        summaries: [SummaryItem],
        markdownStyle: Bool,
        scope: ExportTextScope
    ) {
        let sections: [(String, [SummaryItem])] = [
            (SummaryItem.ItemType.overview.sectionTitle, summaries.filter { $0.type == .overview }),
            (SummaryItem.ItemType.decision.sectionTitle, summaries.filter { $0.type == .decision }),
            (SummaryItem.ItemType.actionItem.sectionTitle, summaries.filter { $0.type == .actionItem }),
            (SummaryItem.ItemType.openQuestion.sectionTitle, summaries.filter { $0.type == .openQuestion })
        ]

        if summaries.isEmpty {
            if scope != .actionsOnly, normalizedReviewSummary(reviewSummary) != nil {
                return
            }

            output += emptyStateText(for: scope, markdownStyle: markdownStyle)
            return
        }

        for (title, items) in sections where !items.isEmpty {
            output += markdownStyle ? "## \(title)\n" : "\(title)\n"

            if !markdownStyle {
                output += String(repeating: "-", count: title.count) + "\n"
            }

            for item in items {
                if item.type == .actionItem {
                    let status = item.actionStatus == .done ? "[x]" : "[ ]"
                    output += "- \(status) \(item.content)\n"
                } else {
                    output += "- \(item.content)\n"
                }
            }

            output += "\n"
        }
    }

    private func appendReviewSummary(
        to output: inout String,
        reviewSummary: String?,
        markdownStyle: Bool,
        scope: ExportTextScope
    ) {
        guard scope != .actionsOnly,
              let reviewSummary = normalizedReviewSummary(reviewSummary) else {
            return
        }

        if markdownStyle {
            output += "## Summary\n\(reviewSummary)\n\n"
        } else {
            output += "Summary\n-------\n\(reviewSummary)\n\n"
        }
    }

    private func filteredSummaries(for scope: ExportTextScope, from summaries: [SummaryItem]) -> [SummaryItem] {
        switch scope {
        case .fullSession:
            return summaries
        case .summaryNotes:
            return summaries.filter { $0.type != .actionItem }
        case .actionsOnly:
            return summaries.filter { $0.type == .actionItem }
        }
    }

    private func emptyStateText(for scope: ExportTextScope, markdownStyle: Bool) -> String {
        switch scope {
        case .fullSession, .summaryNotes:
            return markdownStyle
                ? "## Summary\nNo summary items available.\n\n"
                : "Summary\n-------\nNo summary items available.\n\n"
        case .actionsOnly:
            return markdownStyle
                ? "## \(SummaryItem.ItemType.actionItem.sectionTitle)\nNo action items available.\n\n"
                : "\(SummaryItem.ItemType.actionItem.sectionTitle)\n------------\nNo action items available.\n\n"
        }
    }

    private func normalizedReviewSummary(_ reviewSummary: String?) -> String? {
        let trimmed = reviewSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

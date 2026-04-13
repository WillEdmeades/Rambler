import Foundation
import OSLog

final class StorageService {
    static let shared = StorageService()
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.WillEdmeades.Rambler", category: "Storage")
    
    private var artifactDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Artifacts", isDirectory: true)
    }
    
    private init() {
        do {
            try ensureArtifactDirectoryExists()
        } catch {
            logger.error("Failed to create artifact directory: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func saveTranscript(_ segments: [TranscriptSegment], uuid: UUID) throws -> URL {
        try ensureArtifactDirectoryExists()
        let data = try JSONEncoder().encode(segments)
        let url = artifactDirectory.appendingPathComponent("\(uuid.uuidString)_transcript.json")
        try data.write(to: url)
        return url
    }
    
    func saveSummaries(_ items: [SummaryItem], uuid: UUID) throws -> URL {
        try saveReview(ReviewArtifact(summaryItems: items), uuid: uuid)
    }

    func saveReview(_ review: ReviewArtifact, uuid: UUID) throws -> URL {
        try ensureArtifactDirectoryExists()
        let data = try JSONEncoder().encode(review)
        let url = artifactDirectory.appendingPathComponent("\(uuid.uuidString)_summaries.json")
        try data.write(to: url)
        return url
    }

    func saveReviewSummary(_ proseSummary: String, items: [SummaryItem], uuid: UUID) throws -> URL {
        try saveReview(ReviewArtifact(proseSummary: proseSummary, summaryItems: items), uuid: uuid)
    }
    
    func loadTranscript(from url: URL) -> [TranscriptSegment]? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TranscriptSegment].self, from: data)
        } catch {
            logger.error("Failed to load transcript from \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    func loadSummaries(from url: URL) -> [SummaryItem]? {
        loadReview(from: url)?.summaryItems
    }

    func loadReview(from url: URL) -> ReviewArtifact? {
        do {
            let data = try Data(contentsOf: url)
            if let review = try? JSONDecoder().decode(ReviewArtifact.self, from: data) {
                return review
            }

            let legacyItems = try JSONDecoder().decode([SummaryItem].self, from: data)
            return ReviewArtifact(summaryItems: legacyItems)
        } catch {
            logger.error("Failed to load review from \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func ensureArtifactDirectoryExists() throws {
        try fileManager.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
    }
}

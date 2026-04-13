import Foundation
import OSLog
import SwiftData

enum SessionRepositoryError: LocalizedError {
    case failedToPersistTranscript(Error)
    case failedToSaveContext(Error)

    var errorDescription: String? {
        switch self {
        case .failedToPersistTranscript(let error):
            return "The transcript couldn't be saved to disk. \(error.localizedDescription)"
        case .failedToSaveContext(let error):
            return "The session metadata couldn't be saved. \(error.localizedDescription)"
        }
    }
}

final class SessionRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.WillEdmeades.Rambler", category: "SessionRepository")
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func saveCompletedSession(title: String, duration: TimeInterval, audioURL: URL?, transcriptSegments: [TranscriptSegment], bookmarks: [TimeInterval] = []) throws {
        let recording = Recording(
            title: title.isEmpty ? "New Session" : title,
            duration: duration,
            audioFileURL: audioURL
        )
        let indexedSession = SearchIndexService.IndexedSession(recording: recording)
        recording.bookmarks = bookmarks
        
        if !transcriptSegments.isEmpty {
            do {
                recording.transcriptFileURL = try StorageService.shared.saveTranscript(transcriptSegments, uuid: recording.id)
            } catch {
                throw SessionRepositoryError.failedToPersistTranscript(error)
            }
        }
        
        context.insert(recording)
        do {
            try context.save()
            Task {
                await SearchIndexService.index(indexedSession)
            }
        } catch {
            throw SessionRepositoryError.failedToSaveContext(error)
        }
    }
    
    func deleteSession(_ recording: Recording) {
        let recordingID = recording.id
        removeArtifactIfPresent(recording.audioFileURL)
        removeArtifactIfPresent(recording.transcriptFileURL)
        removeArtifactIfPresent(recording.summaryFileURL)
        
        context.delete(recording)
        do {
            try context.save()
            Task {
                await SearchIndexService.removeRecording(id: recordingID)
            }
        } catch {
            logger.error("Failed to save deletion changes: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func fetchAllRecordings() throws -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return try context.fetch(descriptor)
    }

    private func removeArtifactIfPresent(_ url: URL?) {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Failed to remove artifact \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

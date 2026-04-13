import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var title: String
    var timestamp: Date
    var duration: TimeInterval
    var audioFilename: String?
    var transcriptFilename: String?
    var summaryFilename: String?
    var isPinned: Bool = false
    var bookmarks: [TimeInterval] = []

    // MARK: - Resolved URLs

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var artifactsDirectory: URL {
        documentsDirectory.appendingPathComponent("Artifacts", isDirectory: true)
    }

    @Transient var audioFileURL: URL? {
        get { audioFilename.map { Self.documentsDirectory.appendingPathComponent($0) } }
        set { audioFilename = newValue?.lastPathComponent }
    }

    @Transient var transcriptFileURL: URL? {
        get { transcriptFilename.map { Self.artifactsDirectory.appendingPathComponent($0) } }
        set { transcriptFilename = newValue?.lastPathComponent }
    }

    @Transient var summaryFileURL: URL? {
        get { summaryFilename.map { Self.artifactsDirectory.appendingPathComponent($0) } }
        set { summaryFilename = newValue?.lastPathComponent }
    }

    init(id: UUID = UUID(), title: String = "New Recording", timestamp: Date = Date(), duration: TimeInterval = 0, audioFileURL: URL? = nil, transcriptFileURL: URL? = nil, summaryFileURL: URL? = nil, isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.duration = duration
        self.audioFilename = audioFileURL?.lastPathComponent
        self.transcriptFilename = transcriptFileURL?.lastPathComponent
        self.summaryFilename = summaryFileURL?.lastPathComponent
        self.isPinned = isPinned
    }
}

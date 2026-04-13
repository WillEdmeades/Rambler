import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

enum SearchIndexService {
    struct IndexedSession: Sendable, Hashable {
        let id: UUID
        let title: String
        let timestamp: Date
        let duration: TimeInterval

        init(recording: Recording) {
            id = recording.id
            title = recording.title
            timestamp = recording.timestamp
            duration = recording.duration
        }
    }

    @MainActor
    static func reindex(_ recordings: [Recording]) async {
        await reindex(recordings.map { IndexedSession(recording: $0) })
    }

    @MainActor
    static func reindex(_ recordings: [IndexedSession]) async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let items = recordings.map(makeItem)

        await withCheckedContinuation { continuation in
            CSSearchableIndex.default().indexSearchableItems(items) { _ in
                continuation.resume()
            }
        }
    }

    @MainActor
    static func index(_ recording: IndexedSession) async {
        await reindex([recording])
    }

    @MainActor
    static func removeRecording(id: UUID) async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        await withCheckedContinuation { continuation in
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { _ in
                continuation.resume()
            }
        }
    }

    private static func makeItem(for recording: IndexedSession) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = recording.title
        attributeSet.contentDescription = [
            "Conversation recording",
            recording.timestamp.formatted(date: .abbreviated, time: .shortened),
            RamblerFormatters.accessibilityDuration(recording.duration)
        ].joined(separator: " • ")
        attributeSet.contentCreationDate = recording.timestamp
        attributeSet.keywords = [
            "Rambler",
            "conversation",
            "recording",
            recording.title
        ]

        return CSSearchableItem(
            uniqueIdentifier: recording.id.uuidString,
            domainIdentifier: "com.WillEdmeades.Rambler.sessions",
            attributeSet: attributeSet
        )
    }
}

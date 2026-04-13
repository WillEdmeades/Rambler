import Foundation

struct TranscriptSegment: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var isFinal: Bool
}

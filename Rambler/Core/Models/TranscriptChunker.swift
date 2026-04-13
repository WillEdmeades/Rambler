import Foundation

struct TranscriptChunk: Sendable {
    let id: UUID
    let segments: [TranscriptSegment]
    
    var approximateTokenCount: Int {
        segments.reduce(0) { $0 + $1.text.split(separator: " ").count * 2 }
    }
}

final class TranscriptChunker {
    let maxTokens: Int
    let overlapTokens: Int
    
    init(maxTokens: Int = 1500, overlapTokens: Int = 200) {
        self.maxTokens = maxTokens
        self.overlapTokens = overlapTokens
    }
    
    func generateChunks(from segments: [TranscriptSegment]) -> [TranscriptChunk] {
        var chunks: [TranscriptChunk] = []
        var currentBatch: [TranscriptSegment] = []
        var currentCount = 0
        
        for segment in segments {
            let count = segment.text.split(separator: " ").count * 2
            
            if currentCount + count > maxTokens && !currentBatch.isEmpty {
                chunks.append(TranscriptChunk(id: UUID(), segments: currentBatch))
                
                var overlapBatch: [TranscriptSegment] = []
                var overlapCount = 0
                for seg in currentBatch.reversed() {
                    let segCount = seg.text.split(separator: " ").count * 2
                    if overlapCount + segCount > overlapTokens { break }
                    overlapBatch.insert(seg, at: 0)
                    overlapCount += segCount
                }
                currentBatch = overlapBatch
                currentCount = overlapCount
            }
            
            currentBatch.append(segment)
            currentCount += count
        }
        
        if !currentBatch.isEmpty {
            chunks.append(TranscriptChunk(id: UUID(), segments: currentBatch))
        }
        
        return chunks
    }
}

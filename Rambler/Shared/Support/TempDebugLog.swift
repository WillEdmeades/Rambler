import Foundation

enum TempDebugLog {
    private static let fileManager = FileManager.default
    private static let queue = DispatchQueue(label: "com.WillEdmeades.Rambler.TempDebugLog")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let isEnabled = true

    static var fileURL: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory
            .appendingPathComponent("Artifacts", isDirectory: true)
            .appendingPathComponent("Debug", isDirectory: true)
            .appendingPathComponent("transcript-correction-debug.log")
    }

    static func append(_ message: String) {
        guard isEnabled else { return }

        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        let consoleLine = "[TranscriptDebug] \(message)"

        print(consoleLine)

        queue.async {
            do {
                let directory = fileURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

                if fileManager.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: Data(line.utf8))
                } else {
                    try line.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                // Temporary debug logging should never interrupt the app flow.
            }
        }
    }
}

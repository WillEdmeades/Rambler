import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class ActiveRecordingViewModel {
    enum RecordingState: Equatable {
        case starting
        case recording
        case paused
        case stopping
        case postProcessing
    }
    
    var state: RecordingState = .starting
    var elapsedSeconds: TimeInterval = 0
    let configuration: CaptureConfiguration
    var sessionTitle: String { configuration.normalizedTitle }
    
    var showErrorAlert: Bool = false
    var errorMessage: String = ""
    
    private let captureService = AudioCaptureService()
    private let transcriptionService = TranscriptionService()
    private let liveActivityManager = RecordingLiveActivityManager()
    private let logger = Logger(subsystem: "com.WillEdmeades.Rambler", category: "ActiveRecording")
    let sessionID = UUID()
    
    var transcriptSegments: [TranscriptSegment] { transcriptionService.segments }
    var volatileTranscript: String { transcriptionService.volatileText }
    var isTranscriptFallbackActive: Bool { transcriptionService.isFallbackModeActive }
    
    var audioLevel: Float {
        captureService.currentLevel
    }
    
    var stateLabel: String {
        switch state {
        case .starting: "Starting"
        case .recording: "Recording"
        case .paused: "Paused"
        case .stopping: "Stopping"
        case .postProcessing: "Processing"
        }
    }
    
    private var timer: Timer?
    private var bookmarks: [TimeInterval] = []
    
    private var hasStarted = false
    
    init(configuration: CaptureConfiguration) {
        self.configuration = configuration
    }
    
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        state = .starting
        
        let transcriptionService = self.transcriptionService
        captureService.onAudioBuffer = { buffer in
            transcriptionService.appendAudioBuffer(buffer)
        }

        Task { [weak self] in
            await self?.beginCaptureFlow()
        }
    }
    
    func togglePause() {
        if state == .recording {
            captureService.pauseCapture()
            state = .paused
            stopTimer()
            let transcriptionService = self.transcriptionService
            Task { [weak self] in
                await transcriptionService.pauseTranscription()
                await self?.refreshLiveActivity()
            }
        } else if state == .paused {
            state = .starting
            Task { [weak self] in
                await self?.resumeCaptureFlow()
            }
        }
    }
    
    func stopAndReview(context: ModelContext, onFinish: @escaping () -> Void) {
        state = .stopping
        stopTimer()
        captureService.stopCapture()
        Task { [weak self] in
            await self?.refreshLiveActivity()
        }

        let audioURL = captureService.recordingURL
        let finalTitle = sessionTitle
        let finalDuration = elapsedSeconds

        Task { [weak self] in
            await self?.finishCapture(
                context: context,
                audioURL: audioURL,
                finalTitle: finalTitle,
                finalDuration: finalDuration,
                onFinish: onFinish
            )
        }
    }

    func discardRecording(onDiscard: @escaping () -> Void) {
        state = .stopping
        stopTimer()
        captureService.stopCapture()
        Task { [weak self] in
            await self?.refreshLiveActivity()
        }

        let recordingURL = captureService.recordingURL

        Task { [weak self] in
            await self?.performDiscard(recordingURL: recordingURL, onDiscard: onDiscard)
        }
    }
    
    func addBookmark() {
        bookmarks.append(elapsedSeconds)
    }

    private func beginCaptureFlow() async {
        _ = await transcriptionService.startTranscription(localeIdentifier: configuration.localeIdentifier)

        do {
            try captureService.startCapture(sessionID: sessionID)
            state = .recording
            startTimer()
            await startLiveActivity()
        } catch let error as LocalizedError {
            state = .stopping
            errorMessage = error.errorDescription ?? "Unknown hardware error."
            showErrorAlert = true
            await endLiveActivity()
        } catch {
            state = .stopping
            errorMessage = "Failed to start hardware capture."
            showErrorAlert = true
            await endLiveActivity()
        }
    }

    private func resumeCaptureFlow() async {
        _ = await transcriptionService.resumeTranscription()

        do {
            try captureService.resumeCapture()
            state = .recording
            startTimer()
            await refreshLiveActivity()
        } catch {
            state = .stopping
            errorMessage = error.localizedDescription
            showErrorAlert = true
            await endLiveActivity()
        }
    }

    private func finishCapture(
        context: ModelContext,
        audioURL: URL?,
        finalTitle: String,
        finalDuration: TimeInterval,
        onFinish: @escaping () -> Void
    ) async {
        let segments = await transcriptionService.finishTranscription()
        try? await Task.sleep(for: .milliseconds(500))
        state = .postProcessing
        await refreshLiveActivity()

        let repo = SessionRepository(context: context)
        do {
            try repo.saveCompletedSession(
                title: finalTitle,
                duration: finalDuration,
                audioURL: audioURL,
                transcriptSegments: segments,
                bookmarks: bookmarks
            )
            await endLiveActivity()
            onFinish()
        } catch {
            state = .stopping
            errorMessage = error.localizedDescription
            showErrorAlert = true
            await endLiveActivity()
        }
    }

    private func performDiscard(recordingURL: URL?, onDiscard: @escaping () -> Void) async {
        _ = await transcriptionService.finishTranscription()

        if let recordingURL {
            do {
                try FileManager.default.removeItem(at: recordingURL)
            } catch {
                logger.error("Failed to discard temporary audio: \(error.localizedDescription, privacy: .public)")
            }
        }

        await endLiveActivity()
        onDiscard()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1.0
                await self?.refreshLiveActivity()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startLiveActivity() async {
        await liveActivityManager.start(
            title: sessionTitle,
            elapsedSeconds: elapsedSeconds,
            stateLabel: stateLabel,
            isPaused: state == .paused,
            isTranscriptFallbackActive: isTranscriptFallbackActive
        )
    }

    private func refreshLiveActivity() async {
        await liveActivityManager.update(
            elapsedSeconds: elapsedSeconds,
            stateLabel: stateLabel,
            isPaused: state == .paused,
            isTranscriptFallbackActive: isTranscriptFallbackActive
        )
    }

    private func endLiveActivity() async {
        await liveActivityManager.end()
    }
}

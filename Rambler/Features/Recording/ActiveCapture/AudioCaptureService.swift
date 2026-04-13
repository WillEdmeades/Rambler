import Foundation
import AVFoundation
import Observation
import OSLog

enum AudioCaptureError: Error, LocalizedError {
    case permissionDenied
    case sessionSetupFailed
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone permission was denied."
        case .sessionSetupFailed: return "Failed to configure the audio session."
        case .recordingFailed: return "Failed to start audio recording."
        }
    }
}

@Observable
final class AudioCaptureService {
    var isRecording = false
    var isPaused = false
    var currentLevel: Float = 0.0
    var recordingURL: URL?
    var error: AudioCaptureError?
    
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    private let logger = Logger(subsystem: "com.WillEdmeades.Rambler", category: "AudioCapture")
    private var audioEngine: AVAudioEngine?
    private let tapLock = NSLock()
    private var tapAudioFile: AVAudioFile?
    private var tapIsActive = false
    private var tapWriteFailureLogged = false
    
    nonisolated static func checkMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startCapture(sessionID: UUID) throws {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentDirectory.appendingPathComponent("\(sessionID.uuidString).m4a")
        self.recordingURL = url
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = .sessionSetupFailed
            throw AudioCaptureError.sessionSetupFailed
        }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            self.error = .recordingFailed
            throw AudioCaptureError.recordingFailed
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(
                forWriting: url,
                settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: recordingFormat.sampleRate,
                    AVNumberOfChannelsKey: recordingFormat.channelCount,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ],
                commonFormat: recordingFormat.commonFormat,
                interleaved: recordingFormat.isInterleaved
            )
        } catch {
            self.error = .recordingFailed
            throw AudioCaptureError.recordingFailed
        }
        
        tapLock.lock()
        tapAudioFile = file
        tapIsActive = true
        tapWriteFailureLogged = false
        tapLock.unlock()

        let lock = self.tapLock
        let bufferCallback = self.onAudioBuffer
        let logger = self.logger
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            lock.lock()
            let isActive = self?.tapIsActive ?? false
            let audioFile = self?.tapAudioFile
            lock.unlock()

            guard isActive else { return }

            do {
                try audioFile?.write(from: buffer)
            } catch {
                lock.lock()
                let shouldLog = self?.tapWriteFailureLogged == false
                self?.tapWriteFailureLogged = true
                lock.unlock()

                if shouldLog {
                    logger.error("Failed to write captured audio: \(error.localizedDescription, privacy: .public)")
                }
            }

            bufferCallback?(buffer)

            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                if frameLength > 0 {
                    var sum: Float = 0
                    for i in 0..<frameLength { sum += abs(channelData[i]) }
                    let normalized = min(1.0, (sum / Float(frameLength)) * 10.0)
                    DispatchQueue.main.async { [weak self] in
                        self?.currentLevel = normalized
                    }
                }
            }
        }
        
        do {
            engine.prepare()
            try engine.start()
            self.audioEngine = engine
            isRecording = true
            isPaused = false
        } catch {
            tapLock.lock()
            tapIsActive = false
            tapAudioFile = nil
            tapWriteFailureLogged = false
            tapLock.unlock()
            self.error = .recordingFailed
            throw AudioCaptureError.recordingFailed
        }
    }
    
    func pauseCapture() {
        tapLock.lock()
        tapIsActive = false
        tapWriteFailureLogged = false
        tapLock.unlock()
        
        audioEngine?.pause()
        isPaused = true
        isRecording = false
    }
    
    func resumeCapture() throws {
        do {
            try audioEngine?.start()
        } catch {
            self.error = .recordingFailed
            throw AudioCaptureError.recordingFailed
        }
        
        tapLock.lock()
        tapIsActive = true
        tapWriteFailureLogged = false
        tapLock.unlock()
        
        isRecording = true
        isPaused = false
    }
    
    func stopCapture() {
        tapLock.lock()
        tapIsActive = false
        tapAudioFile = nil
        tapWriteFailureLogged = false
        tapLock.unlock()
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        isPaused = false
        currentLevel = 0.0
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription, privacy: .public)")
        }
    }
}

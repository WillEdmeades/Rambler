import AVFoundation
import CoreMedia
import Foundation
import Observation
import Speech

enum TranscriptionError: LocalizedError {
    case transcriberUnavailable
    case localeNotSupported
    case invalidAudioFormat
    case failedToConfigureAnalyzer

    var errorDescription: String? {
        switch self {
        case .transcriberUnavailable:
            return "SpeechTranscriber is unavailable on this device."
        case .localeNotSupported:
            return "The selected language isn't supported for on-device transcription."
        case .invalidAudioFormat:
            return "The live audio stream couldn't be converted into a format supported by SpeechAnalyzer."
        case .failedToConfigureAnalyzer:
            return "The on-device speech analysis session couldn't be configured."
        }
    }
}

private struct TranscriptSegmentFactory {
    func makeSegment(id: UUID = UUID(), text: String, range: CMTimeRange) -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            startTime: max(0, range.start.seconds),
            endTime: max(0, CMTimeRangeGetEnd(range).seconds),
            text: text,
            isFinal: true
        )
    }
}

private final class AudioBufferConverter {
    private let lock = NSLock()
    private var cachedConverters: [String: AVAudioConverter] = [:]

    func convertBuffer(_ buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard !matches(buffer.format, targetFormat) else {
            return buffer
        }

        let converter = try converter(from: buffer.format, to: targetFormat)
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let estimatedCapacity = max(Int(ceil(Double(buffer.frameLength) * ratio)), 1)

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(estimatedCapacity)
        ) else {
            throw TranscriptionError.invalidAudioFormat
        }

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return convertedBuffer
        case .error:
            throw error ?? TranscriptionError.invalidAudioFormat
        @unknown default:
            throw TranscriptionError.invalidAudioFormat
        }
    }

    private func converter(from sourceFormat: AVAudioFormat, to targetFormat: AVAudioFormat) throws -> AVAudioConverter {
        let cacheKey = converterKey(source: sourceFormat, target: targetFormat)

        lock.lock()
        defer { lock.unlock() }

        if let cachedConverter = cachedConverters[cacheKey] {
            return cachedConverter
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw TranscriptionError.invalidAudioFormat
        }

        cachedConverters[cacheKey] = converter
        return converter
    }

    private func matches(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.sampleRate == rhs.sampleRate &&
        lhs.channelCount == rhs.channelCount &&
        lhs.commonFormat == rhs.commonFormat &&
        lhs.isInterleaved == rhs.isInterleaved
    }

    private func converterKey(source: AVAudioFormat, target: AVAudioFormat) -> String {
        [
            "\(source.sampleRate)",
            "\(source.channelCount)",
            "\(source.commonFormat.rawValue)",
            source.isInterleaved ? "1" : "0",
            "\(target.sampleRate)",
            "\(target.channelCount)",
            "\(target.commonFormat.rawValue)",
            target.isInterleaved ? "1" : "0"
        ].joined(separator: "|")
    }
}

@Observable
final class TranscriptionService {
    var segments: [TranscriptSegment] = []
    var volatileText: String = ""
    var isTranscribing: Bool = false
    var isFallbackModeActive: Bool = false

    private let segmentFactory = TranscriptSegmentFactory()
    private let bufferConverter = AudioBufferConverter()
    private let analyzerStateLock = NSLock()

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var analyzerFormat: AVAudioFormat?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    private var activeLocaleIdentifier: String = "en-US"
    private var hasConfiguredSession = false

    @discardableResult
    func startTranscription(localeIdentifier: String) async -> Bool {
        activeLocaleIdentifier = localeIdentifier
        let shouldResetTranscript = !hasConfiguredSession
        let started = await configureTranscriptionSession(resetTranscript: shouldResetTranscript)
        if started {
            hasConfiguredSession = true
        }
        return started
    }

    @discardableResult
    func resumeTranscription() async -> Bool {
        await configureTranscriptionSession(resetTranscript: false)
    }

    func pauseTranscription() async {
        await finalizeCurrentSession()
    }

    func finishTranscription() async -> [TranscriptSegment] {
        await finalizeCurrentSession()
        return await MainActor.run { segments }
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        analyzerStateLock.lock()
        let currentAnalyzerFormat = analyzerFormat
        let currentInputBuilder = inputBuilder
        analyzerStateLock.unlock()

        guard let currentAnalyzerFormat, let currentInputBuilder else { return }

        do {
            let convertedBuffer = try bufferConverter.convertBuffer(buffer, to: currentAnalyzerFormat)
            currentInputBuilder.yield(AnalyzerInput(buffer: convertedBuffer))
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isTranscribing = false
                self?.isFallbackModeActive = true
                self?.volatileText = ""
            }
        }
    }

    private func configureTranscriptionSession(resetTranscript: Bool) async -> Bool {
        do {
            await cancelCurrentSessionImmediately()
            try await prepareTranscriberIfNeeded(for: activeLocaleIdentifier)
            await MainActor.run {
                if resetTranscript {
                    self.segments.removeAll()
                }
                self.volatileText = ""
            }
            try await startTranscriptionPipeline()

            await MainActor.run {
                self.isTranscribing = true
                self.isFallbackModeActive = false
            }
            return true
        } catch {
            await MainActor.run {
                self.volatileText = ""
                self.isTranscribing = false
                self.isFallbackModeActive = true
            }
            return false
        }
    }

    private func prepareTranscriberIfNeeded(for localeIdentifier: String) async throws {
        guard SpeechTranscriber.isAvailable else {
            throw TranscriptionError.transcriberUnavailable
        }

        let readiness = await SpeechAssetService.checkSpeechReadiness(for: localeIdentifier)
        guard readiness.supportReady else {
            throw TranscriptionError.localeNotSupported
        }

        if !readiness.assetsReady {
            try await SpeechAssetService.installAssets(for: localeIdentifier)
        }
    }

    private func startTranscriptionPipeline() async throws {
        let requestedLocale = Locale(identifier: activeLocaleIdentifier)
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw TranscriptionError.localeNotSupported
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.failedToConfigureAnalyzer
        }
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        try await analyzer.start(inputSequence: inputSequence)

        storeAnalyzerSession(
            analyzer: analyzer,
            transcriber: transcriber,
            analyzerFormat: analyzerFormat,
            inputBuilder: inputBuilder
        )

        startResultsTask(for: transcriber)
    }

    private func startResultsTask(for transcriber: SpeechTranscriber) {
        resultsTask?.cancel()
        resultsTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    let range = result.range
                    let isFinal = result.isFinal
                    await self.publishRecognitionResult(text: text, range: range, isFinal: isFinal)
                }
            } catch is CancellationError {
                return
            } catch {
                await self.publishRecognitionFailure()
            }
        }
    }

    private func publishRecognitionResult(text: String, range: CMTimeRange, isFinal: Bool) async {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if isFinal {
            await MainActor.run {
                self.volatileText = ""
            }

            guard !normalizedText.isEmpty else { return }

            let segment = segmentFactory.makeSegment(text: normalizedText, range: range)
            await MainActor.run {
                self.segments.append(segment)
            }
            return
        }

        await MainActor.run {
            self.volatileText = normalizedText
        }
    }

    private func publishRecognitionFailure() async {
        await MainActor.run {
            self.volatileText = ""
            self.isTranscribing = false
            self.isFallbackModeActive = true
        }
    }

    private func finalizeCurrentSession() async {
        let activeAnalyzer = finishInputAndCurrentAnalyzer()

        do {
            try await activeAnalyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            await activeAnalyzer?.cancelAndFinishNow()
        }

        await resultsTask?.value

        clearAnalyzerSession()
        resultsTask = nil

        await MainActor.run {
            self.volatileText = ""
            self.isTranscribing = false
        }
    }

    private func cancelCurrentSessionImmediately() async {
        let activeAnalyzer = takeAndClearAnalyzerSession()

        resultsTask?.cancel()
        resultsTask = nil
        await activeAnalyzer?.cancelAndFinishNow()
    }

    private func storeAnalyzerSession(
        analyzer: SpeechAnalyzer,
        transcriber: SpeechTranscriber,
        analyzerFormat: AVAudioFormat,
        inputBuilder: AsyncStream<AnalyzerInput>.Continuation
    ) {
        analyzerStateLock.lock()
        self.transcriber = transcriber
        self.analyzer = analyzer
        self.analyzerFormat = analyzerFormat
        self.inputBuilder = inputBuilder
        analyzerStateLock.unlock()
    }

    private func finishInputAndCurrentAnalyzer() -> SpeechAnalyzer? {
        analyzerStateLock.lock()
        inputBuilder?.finish()
        let activeAnalyzer = analyzer
        analyzerStateLock.unlock()
        return activeAnalyzer
    }

    private func clearAnalyzerSession() {
        analyzerStateLock.lock()
        analyzer = nil
        transcriber = nil
        analyzerFormat = nil
        inputBuilder = nil
        analyzerStateLock.unlock()
    }

    private func takeAndClearAnalyzerSession() -> SpeechAnalyzer? {
        analyzerStateLock.lock()
        inputBuilder?.finish()
        let activeAnalyzer = analyzer
        analyzer = nil
        transcriber = nil
        analyzerFormat = nil
        inputBuilder = nil
        analyzerStateLock.unlock()
        return activeAnalyzer
    }
}

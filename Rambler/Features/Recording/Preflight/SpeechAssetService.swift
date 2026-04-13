import Foundation
import Speech

struct SpeechReadinessStatus: Equatable, Sendable {
    var supportReady: Bool
    var assetsReady: Bool
    var statusMessage: String
}

enum SpeechAssetError: LocalizedError {
    case transcriberUnavailable
    case localeUnsupported

    var errorDescription: String? {
        switch self {
        case .transcriberUnavailable:
            return "SpeechTranscriber is unavailable on this device."
        case .localeUnsupported:
            return "The selected language isn't supported for on-device transcription."
        }
    }
}

enum SpeechAssetService {
    static func checkSpeechReadiness(for localeIdentifier: String) async -> SpeechReadinessStatus {
        guard SpeechTranscriber.isAvailable else {
            return SpeechReadinessStatus(
                supportReady: false,
                assetsReady: false,
                statusMessage: "SpeechTranscriber is unavailable on this device."
            )
        }

        guard let supportedLocale = await resolvedSupportedLocale(for: localeIdentifier) else {
            return SpeechReadinessStatus(
                supportReady: false,
                assetsReady: false,
                statusMessage: "The selected language isn't supported for on-device transcription."
            )
        }

        let installedLocales = Set(await SpeechTranscriber.installedLocales)
        let localeTag = supportedLocale.identifier(.bcp47)
        let assetsReady = installedLocales.contains { $0.identifier(.bcp47) == localeTag }

        if assetsReady {
            return SpeechReadinessStatus(
                supportReady: true,
                assetsReady: true,
                statusMessage: "Speech transcription is ready for \(localeTag)."
            )
        }

        return SpeechReadinessStatus(
            supportReady: true,
            assetsReady: false,
            statusMessage: "Speech assets for \(localeTag) are available but not installed yet."
        )
    }

    static func installAssets(for localeIdentifier: String) async throws {
        guard SpeechTranscriber.isAvailable else {
            throw SpeechAssetError.transcriberUnavailable
        }

        guard let supportedLocale = await resolvedSupportedLocale(for: localeIdentifier) else {
            throw SpeechAssetError.localeUnsupported
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installationRequest.downloadAndInstall()
        }
    }

    private static func resolvedSupportedLocale(for localeIdentifier: String) async -> Locale? {
        let requestedLocale = Locale(identifier: localeIdentifier)
        if let equivalentLocale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) {
            return equivalentLocale
        }

        let localeTag = requestedLocale.identifier(.bcp47)
        return await SpeechTranscriber.supportedLocales.first { $0.identifier(.bcp47) == localeTag }
    }
}

import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class PreflightViewModel {
    struct LocaleOption: Identifiable, Equatable {
        let identifier: String
        let displayName: String

        var id: String { identifier }
    }

    var sessionTitle: String = ""
    var selectedLocale: String
    var hasConsent: Bool = false
    
    var isMicrophoneReady: Bool = false
    var isSpeechSupportReady: Bool = false
    var areSpeechAssetsDownloaded: Bool = false
    var isSummaryModelAvailable: Bool = false
    var speechStatusMessage: String = "Checking speech support..."

    var canStartRecording: Bool {
        hasConsent && isMicrophoneReady && isSpeechSupportReady
    }
    
    var availableLocales: [LocaleOption] {
        Self.supportedLocales
    }

    init() {
        selectedLocale = Self.defaultLocaleIdentifier
    }
    
    func performHardwareChecks() async {
        let micReady = await AudioCaptureService.checkMicrophonePermission()
        let speechStatus = await SpeechAssetService.checkSpeechReadiness(for: selectedLocale)
        let summaryModelAvailable = SystemLanguageModel.default.availability == .available

        isMicrophoneReady = micReady
        isSpeechSupportReady = speechStatus.supportReady
        areSpeechAssetsDownloaded = speechStatus.assetsReady
        speechStatusMessage = speechStatus.statusMessage
        isSummaryModelAvailable = summaryModelAvailable
    }

    private static let supportedLocales: [LocaleOption] = [
        "en-US",
        "en-GB",
        "es-ES",
        "fr-FR",
        "de-DE"
    ].map {
        LocaleOption(
            identifier: $0,
            displayName: Locale.current.localizedString(forIdentifier: $0) ?? $0
        )
    }

    private static var defaultLocaleIdentifier: String {
        let currentIdentifier = Locale.autoupdatingCurrent.identifier(.bcp47)
        return supportedLocales.first(where: { $0.identifier == currentIdentifier })?.identifier ?? "en-US"
    }
}

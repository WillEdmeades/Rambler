import AppIntents

struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static let description = IntentDescription("Start capturing a new conversation in Rambler.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ramblerStartRecording, object: nil)
        return .result()
    }
}

struct OpenRecentSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Recent Session"
    static let description = IntentDescription("Open the most recently captured conversation.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ramblerOpenRecentSession, object: nil)
        return .result()
    }
}

struct SummarizeRecentSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Latest Session"
    static let description = IntentDescription("Generate a summary for the most recent conversation if it lacks one.")
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ramblerSummarizeRecentSession, object: nil)
        return .result()
    }
}

struct OpenRecentActionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Latest Review"
    static let description = IntentDescription("Open the latest conversation directly in Review.")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ramblerOpenRecentActions, object: nil)
        return .result()
    }
}

struct RamblerShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start a \(.applicationName) recording",
                "Record a conversation in \(.applicationName)"
            ],
            shortTitle: "Record Conversation",
            systemImageName: "waveform.circle"
        )
        AppShortcut(
            intent: OpenRecentSessionIntent(),
            phrases: [
                "Open latest \(.applicationName) session",
                "Show my latest \(.applicationName) recording"
            ],
            shortTitle: "Open Latest Session",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: OpenRecentActionsIntent(),
            phrases: [
                "Open latest \(.applicationName) review",
                "Show latest \(.applicationName) review"
            ],
            shortTitle: "Open Latest Review",
            systemImageName: "text.document"
        )
        AppShortcut(
            intent: SummarizeRecentSessionIntent(),
            phrases: [
                "Summarize latest \(.applicationName) session",
                "Generate \(.applicationName) summary"
            ],
            shortTitle: "Summarize Latest Session",
            systemImageName: "text.document.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor {
        .teal
    }
}

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SessionsListViewModel {
    var searchText: String = ""
    var isCaptureFlowPresented: Bool = false
    var isSettingsPresented: Bool = false
    
    var sessionToRename: Recording?
    var renameTitle: String = ""
    
    func deleteRecording(_ recording: Recording, in context: ModelContext) {
        let repo = SessionRepository(context: context)
        repo.deleteSession(recording)
    }
    
    func togglePin(_ recording: Recording) {
        recording.isPinned.toggle()
    }
    
    func promptRename(_ recording: Recording) {
        renameTitle = recording.title
        sessionToRename = recording
    }
    
    func saveRename() {
        let trimmedTitle = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if let session = sessionToRename, !trimmedTitle.isEmpty {
            session.title = trimmedTitle
        }

        renameTitle = ""
        sessionToRename = nil
    }
}

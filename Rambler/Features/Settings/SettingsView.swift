import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var recordings: [Recording]
    
    @AppStorage(RamblerPreferences.autoGenerateSummaries) private var autoGenerateSummaries = true
    @AppStorage(RamblerPreferences.keepScreenAwakeWhileRecording) private var keepScreenAwakeWhileRecording = true

    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Keep Screen Awake While Recording", isOn: $keepScreenAwakeWhileRecording)
                } header: {
                    Text("Recording")
                } footer: {
                    Text("Prevents Auto-Lock during an active capture on iPhone.")
                }

                Section {
                    Toggle("Prepare Review Automatically", isOn: $autoGenerateSummaries)
                } header: {
                    Text("Review")
                } footer: {
                    Text("When enabled, Rambler prepares a grounded review automatically as transcript content becomes available.")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete All Sessions")
                    }
                    .disabled(recordings.isEmpty)
                } header: {
                    Text("Data")
                } footer: {
                    Text("Deleting all sessions also removes saved audio, transcripts, and summaries from this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllData()
                    dismiss()
                }
            } message: {
                Text("This permanently removes all recordings, transcripts, summaries, and audio files from this device. This cannot be undone.")
            }
        }
    }
    
    private func deleteAllData() {
        let repo = SessionRepository(context: modelContext)
        for rec in Array(recordings) {
            repo.deleteSession(rec)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewFixtures.sampleModelContainer)
}

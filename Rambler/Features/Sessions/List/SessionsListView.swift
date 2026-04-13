import SwiftUI
import SwiftData

struct SessionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.timestamp, order: .reverse) private var recordings: [Recording]
    @State private var viewModel = SessionsListViewModel()
    @State private var isActiveRecordingPresented = false
    @State private var shouldStartCaptureAfterPreflight = false
    @State private var activeCaptureConfiguration = CaptureConfiguration()
    @State private var navigationPath: [Recording] = []

    init() {}

    var filteredRecordings: [Recording] {
        let baseRecordings: [Recording]

        if viewModel.searchText.isEmpty {
            baseRecordings = recordings
        } else {
            baseRecordings = recordings.filter { $0.title.localizedCaseInsensitiveContains(viewModel.searchText) }
        }

        return sortRecordings(baseRecordings)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(filteredRecordings) { recording in
                    NavigationLink(value: recording) {
                        SessionRowView(recording: recording)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { viewModel.deleteRecording(recording, in: modelContext) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation { viewModel.togglePin(recording) }
                        } label: {
                            Label(recording.isPinned ? "Unpin" : "Pin", systemImage: recording.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.orange)
                        
                        Button {
                            viewModel.promptRename(recording)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { offsets in
                    withAnimation {
                        for index in offsets {
                            viewModel.deleteRecording(filteredRecordings[index], in: modelContext)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $viewModel.searchText, prompt: "Search sessions...")
            .overlay {
                if recordings.isEmpty && viewModel.searchText.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "waveform",
                        description: Text("Tap the record button to start your first capture.")
                    )
                } else if filteredRecordings.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { viewModel.isSettingsPresented = true }) {
                        Image(systemName: "gear")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Settings")
                }
                
                ToolbarItem(placement: .bottomBar) {
                    captureButton
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(
                isPresented: $viewModel.isCaptureFlowPresented,
                onDismiss: {
                    guard shouldStartCaptureAfterPreflight else { return }
                    shouldStartCaptureAfterPreflight = false
                    isActiveRecordingPresented = true
                }
            ) {
                PreflightView { configuration in
                    activeCaptureConfiguration = configuration
                    shouldStartCaptureAfterPreflight = true
                }
            }
            .fullScreenCover(isPresented: $isActiveRecordingPresented) {
                ActiveRecordingView(configuration: activeCaptureConfiguration)
            }
            .sheet(isPresented: $viewModel.isSettingsPresented) {
                SettingsView()
                    .presentationDetents([.medium, .large])
            }
            .alert("Rename Session", isPresented: .init(get: { viewModel.sessionToRename != nil }, set: { if !$0 { viewModel.sessionToRename = nil } })) {
                TextField("Title", text: $viewModel.renameTitle)
                Button("Cancel", role: .cancel) { viewModel.sessionToRename = nil }
                Button("Save") { viewModel.saveRename() }
                    .disabled(viewModel.renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationDestination(for: Recording.self) { recording in
                SessionDetailView(recording: recording)
            }
            .onReceive(NotificationCenter.default.publisher(for: .ramblerStartRecording)) { _ in
                viewModel.isCaptureFlowPresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .ramblerOpenRecentSession)) { _ in
                openMostRecentSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: .ramblerSummarizeRecentSession)) { _ in
                openMostRecentSession(shouldGenerateSummary: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .ramblerOpenRecentActions)) { _ in
                openMostRecentSession(preferredTab: .review)
            }
            .task(id: searchIndexSignature) {
                await SearchIndexService.reindex(recordings)
            }
        }
    }
    
    private var captureButton: some View {
        Button(action: { viewModel.isCaptureFlowPresented = true }) {
            Image(systemName: "mic.fill")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.red)
        .accessibilityLabel("Start Recording")
        .accessibilityHint("Opens the preflight check to begin a new capture.")
    }

    private func sortRecordings(_ recordings: [Recording]) -> [Recording] {
        recordings.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }

            return $0.timestamp > $1.timestamp
        }
    }

    private var searchIndexSignature: [String] {
        recordings.map {
            [
                $0.id.uuidString,
                $0.title,
                String($0.timestamp.timeIntervalSince1970),
                String($0.duration)
            ].joined(separator: "|")
        }
    }

    private func openMostRecentSession(
        shouldGenerateSummary: Bool = false,
        preferredTab: SessionDetailView.DetailTab? = nil
    ) {
        guard let recent = recordings.max(by: { $0.timestamp < $1.timestamp }) else { return }

        if shouldGenerateSummary {
            IntentState.shared.pendingSummaryTargetID = recent.id
        }

        IntentState.shared.pendingSelectedTab = preferredTab?.rawValue

        navigationPath = [recent]
    }
}

#Preview {
    SessionsListView()
        .modelContainer(PreviewFixtures.sampleModelContainer)
}

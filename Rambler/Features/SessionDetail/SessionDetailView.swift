import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RamblerPreferences.autoGenerateSummaries) private var autoGenerateSummaries = true

    @State private var viewModel: SessionDetailViewModel

    @State private var isRenameAlertPresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var editingTranscriptSegment: TranscriptSegment?
    @State private var renameTitle = ""

    init(recording: Recording) {
        _viewModel = State(initialValue: SessionDetailViewModel(recording: recording))
    }

    enum DetailTab: String, CaseIterable {
        case review = "Review"
        case transcript = "Transcript"
    }

    private var currentTab: Binding<DetailTab> {
        Binding(
            get: { resolvedDetailTab(from: viewModel.selectedTab) },
            set: { viewModel.selectedTab = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            playbackHeader

            Picker("Detail Mode", selection: currentTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch currentTab.wrappedValue {
            case .review:
                ScrollView {
                    SessionReviewView(
                        viewModel: viewModel,
                        showTranscriptForItem: showTranscriptForItem,
                        presentAskRambler: viewModel.presentAskRambler
                    )
                    .padding()
                }

            case .transcript:
                SessionTranscriptView(
                    viewModel: viewModel,
                    editingSegment: $editingTranscriptSegment
                )
            }
        }
        .navigationTitle(viewModel.recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search transcript"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Export", systemImage: "square.and.arrow.up") {
                        viewModel.isExportSheetPresented = true
                    }

                    Button(viewModel.recording.isPinned ? "Unpin" : "Pin", systemImage: viewModel.recording.isPinned ? "pin.slash" : "pin") {
                        withAnimation { viewModel.recording.isPinned.toggle() }
                    }

                    Button("Rename", systemImage: "pencil") {
                        renameTitle = viewModel.recording.title
                        isRenameAlertPresented = true
                    }

                    Divider()

                    Button("Delete", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Session Options")
            }
        }
        .onDisappear {
            if viewModel.isPlaying {
                viewModel.togglePlayback()
            }
        }
        .alert("Rename Session", isPresented: $isRenameAlertPresented) {
            TextField("Session Title", text: $renameTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmedTitle = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty {
                    viewModel.recording.title = trimmedTitle
                }
            }
            .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .sheet(isPresented: $viewModel.isEditSheetPresented) {
            if let item = viewModel.selectedEditItem {
                EditSummaryItemSheet(item: item) { updatedItem in
                    viewModel.saveEditedItem(updatedItem)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $editingTranscriptSegment) { segment in
            EditTranscriptSegmentSheet(
                segment: segment,
                onCancel: {
                    TempDebugLog.append("Parent closing transcript sheet segment=\(segment.id)")
                    editingTranscriptSegment = nil
                },
                onSave: { updatedText in
                    TempDebugLog.append("Parent received transcript save segment=\(segment.id) chars=\(updatedText.count)")
                    let didSave = await viewModel.saveTranscriptCorrection(for: segment, text: updatedText)
                    TempDebugLog.append("Parent transcript save completed segment=\(segment.id) success=\(didSave)")
                    return didSave
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.isAskRamblerSheetPresented) {
            AskRamblerSheet(
                prompt: $viewModel.askRamblerPrompt,
                state: viewModel.askRamblerState,
                sourceEvidence: askRamblerSourceEvidence,
                savedMessage: viewModel.askRamblerSavedMessage,
                onSubmit: {
                    Task { await viewModel.runAskRambler() }
                },
                onQuickAction: { action in
                    Task { await viewModel.runAskRambler(action: action) }
                },
                onApply: { destination in
                    viewModel.applyAskRamblerResponse(to: destination)
                },
                onJumpToSource: askRamblerJumpAction,
                onReset: viewModel.resetAskRambler
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.isExportSheetPresented) {
            ExportSheetView(
                recording: viewModel.recording,
                segments: viewModel.segments,
                reviewSummary: viewModel.normalizedReviewSummary,
                summaries: viewModel.summaryItems
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Delete This Session?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                SessionRepository(context: modelContext).deleteSession(viewModel.recording)
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the audio, transcript, and review from this device.")
        }
        .task(id: viewModel.recording.id) {
            if let pendingSelectedTab = IntentState.shared.pendingSelectedTab {
                viewModel.selectedTab = resolvedDetailTab(from: pendingSelectedTab).rawValue
                IntentState.shared.pendingSelectedTab = nil
            }

            let shouldGenerateSummaryFromIntent = IntentState.shared.pendingSummaryTargetID == viewModel.recording.id

            if shouldGenerateSummaryFromIntent {
                IntentState.shared.pendingSummaryTargetID = nil
                viewModel.selectedTab = DetailTab.review.rawValue
            }

            if (shouldGenerateSummaryFromIntent || autoGenerateSummaries),
               !viewModel.hasReviewContent,
               !viewModel.segments.isEmpty {
                await viewModel.generateSummary()
            }
        }
    }

    private var playbackHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.recording.timestamp, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(RamblerFormatters.recordingClock(viewModel.currentTime) + " / " + RamblerFormatters.recordingClock(viewModel.recording.duration))
                    .font(.headline.monospacedDigit())

                Spacer()

                HStack(spacing: 24) {
                    Button(action: viewModel.seekBackward) {
                        Image(systemName: "gobackward.15")
                    }
                    .accessibilityLabel("Skip Backward 15 Seconds")

                    Button(action: viewModel.togglePlayback) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

                    Button(action: viewModel.seekForward) {
                        Image(systemName: "goforward.15")
                    }
                    .accessibilityLabel("Skip Forward 15 Seconds")
                }
                .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private func resolvedDetailTab(from rawValue: String) -> DetailTab {
        switch rawValue {
        case DetailTab.review.rawValue, "Summary", "Actions":
            return .review
        default:
            return .transcript
        }
    }

    private func showTranscriptForItem(_ item: SummaryItem) {
        viewModel.jumpToSource(of: item)
        viewModel.selectedTab = DetailTab.transcript.rawValue
    }

    private var askRamblerSourceEvidence: SessionDetailViewModel.SourceEvidence? {
        guard case .ready(let response) = viewModel.askRamblerState else { return nil }
        return viewModel.sourceEvidence(for: response.sourceSegmentIDs)
    }

    private var askRamblerJumpAction: (() -> Void)? {
        guard case .ready(let response) = viewModel.askRamblerState,
              !response.sourceSegmentIDs.isEmpty else {
            return nil
        }

        return {
            viewModel.jumpToSourceSegmentIDs(response.sourceSegmentIDs)
            viewModel.selectedTab = DetailTab.transcript.rawValue
            viewModel.isAskRamblerSheetPresented = false
        }
    }
}

#Preview {
    SessionDetailView(recording: PreviewFixtures.recordingWithArtifacts())
        .modelContainer(PreviewFixtures.sampleModelContainer)
}

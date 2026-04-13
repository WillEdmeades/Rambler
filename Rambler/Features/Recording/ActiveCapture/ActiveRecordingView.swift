import SwiftUI
import UIKit

struct ActiveRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(RamblerPreferences.keepScreenAwakeWhileRecording) private var keepScreenAwakeWhileRecording = true
    @State private var viewModel: ActiveRecordingViewModel
    @State private var isDiscardConfirmationPresented = false
    
    init(configuration: CaptureConfiguration) {
        _viewModel = State(initialValue: ActiveRecordingViewModel(configuration: configuration))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if viewModel.isTranscriptFallbackActive {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Transcription Unavailable", systemImage: "exclamationmark.triangle")
                                        .font(.headline)
                                        .foregroundStyle(.orange)
                                    Text("Audio is being captured. You can review the recording later, but live transcription is not available for this device or locale.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                            
                            ForEach(viewModel.transcriptSegments) { segment in
                                Text(segment.text)
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                                    .animation(reduceMotion ? nil : .easeIn(duration: 0.2), value: segment.text)
                            }
                            
                            if !viewModel.volatileTranscript.isEmpty {
                                Text(viewModel.volatileTranscript)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .animation(reduceMotion ? nil : .default, value: viewModel.volatileTranscript)
                                    .id("volatile")
                            }
                            
                            Spacer(minLength: 200)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .onChange(of: viewModel.volatileTranscript.isEmpty) { _, isEmpty in
                            guard !isEmpty else { return }
                            scrollToTranscriptAnchor("volatile", using: proxy)
                        }
                        .onChange(of: viewModel.transcriptSegments.count) { _, _ in
                            if let latestSegmentID = viewModel.transcriptSegments.last?.id {
                                scrollToTranscriptAnchor(latestSegmentID, using: proxy)
                            }
                        }
                    }
                }
                .accessibilityLabel("Live Transcript Output Area")
                
                Divider()

                VStack(spacing: 24) {
                    if viewModel.state == .recording || viewModel.state == .paused {
                        HStack(spacing: 4) {
                            ForEach(0..<15, id: \.self) { index in
                                let maxHeight: CGFloat = 35
                                let targetHeight: CGFloat = (viewModel.state == .recording) ? max(4, CGFloat(viewModel.audioLevel) * maxHeight * ((index % 2 == 0) ? 1.0 : 0.6)) : 4
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(viewModel.state == .recording ? Color.red.opacity(0.6) : Color.gray.opacity(0.4))
                                    .frame(width: 4, height: targetHeight)
                                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: viewModel.audioLevel)
                            }
                        }
                        .frame(height: 45)
                        .accessibilityHidden(true)
                    } else {
                        Spacer().frame(height: 45)
                    }

                    HStack(spacing: 40) {
                        Button(action: { viewModel.addBookmark() }) {
                            Image(systemName: "bookmark.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .frame(width: 50, height: 50)
                                .background(Color.secondary.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Add Bookmark")
                        .disabled(viewModel.state != .recording)
                        
                        Button(action: { viewModel.togglePause() }) {
                            Image(systemName: viewModel.state == .paused ? "mic.fill" : "pause.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .background(viewModel.state == .paused ? Color.blue : Color.orange)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(viewModel.state == .paused ? "Resume Capture" : "Pause Capture")
                        .disabled(viewModel.state == .starting || viewModel.state == .stopping || viewModel.state == .postProcessing)
                        
                        Button(action: { viewModel.stopAndReview(context: modelContext) { dismiss() } }) {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Stop Recording")
                        .accessibilityHint("Ends capture and safely processes audio natively.")
                        .disabled(viewModel.state == .stopping || viewModel.state == .postProcessing)
                    }
                }
                .padding()
                .padding(.bottom, 20)
                .background(Color(.systemBackground).shadow(radius: 2))

                if viewModel.state == .postProcessing {
                    Text("Finalizing capture…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .navigationTitle(viewModel.sessionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        if reduceMotion {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(viewModel.state == .recording ? .red : .gray)
                                .font(.caption)
                        } else {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(viewModel.state == .recording ? .red : .gray)
                                .font(.caption)
                                .symbolEffect(.pulse, options: .repeating, isActive: viewModel.state == .recording)
                        }
                        
                        Text(RamblerFormatters.recordingClock(viewModel.elapsedSeconds))
                            .font(.headline.monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Status: \(viewModel.stateLabel), elapsed time \(RamblerFormatters.accessibilityDuration(viewModel.elapsedSeconds))"))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Discard Recording", role: .destructive) {
                            isDiscardConfirmationPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More Options")
                    .disabled(viewModel.state == .starting || viewModel.state == .postProcessing)
                }
            }
        }
        .background(Color(.systemBackground))
        .task { viewModel.start() }
        .onAppear { updateIdleTimerState() }
        .onDisappear { setIdleTimerDisabled(false) }
        .onChange(of: keepScreenAwakeWhileRecording) { _, _ in
            updateIdleTimerState()
        }
        .onChange(of: viewModel.state) { _, _ in
            updateIdleTimerState()
        }
        .interactiveDismissDisabled(true)
        .alert("Capture Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(viewModel.errorMessage)
        }
        .confirmationDialog(
            "Discard This Recording?",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Recording", role: .destructive) {
                viewModel.discardRecording {
                    dismiss()
                }
            }
            Button("Keep Recording", role: .cancel) {}
        } message: {
            Text("This removes the temporary audio and transcript for the current capture.")
        }
    }

    private func scrollToTranscriptAnchor<Anchor: Hashable>(_ anchor: Anchor, using proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(anchor, anchor: .bottom)
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(anchor, anchor: .bottom)
            }
        }
    }

    private func updateIdleTimerState() {
        let shouldKeepAwake = keepScreenAwakeWhileRecording && [
            ActiveRecordingViewModel.RecordingState.starting,
            .recording,
            .paused,
            .stopping,
            .postProcessing
        ].contains(viewModel.state)

        setIdleTimerDisabled(shouldKeepAwake)
    }

    private func setIdleTimerDisabled(_ isDisabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isDisabled
    }
}

#Preview {
    ActiveRecordingView(configuration: CaptureConfiguration(title: "Interview"))
}

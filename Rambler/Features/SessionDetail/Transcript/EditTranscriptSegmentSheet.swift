import SwiftUI

struct EditTranscriptSegmentSheet: View {
    let segment: TranscriptSegment
    let onCancel: () -> Void
    let onSave: (String) async -> Bool

    @State private var draftText: String
    @State private var isSaving = false
    @FocusState private var isEditorFocused: Bool

    init(
        segment: TranscriptSegment,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) async -> Bool
    ) {
        self.segment = segment
        self.onCancel = onCancel
        self.onSave = onSave
        _draftText = State(initialValue: segment.text)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Timestamp")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(RamblerFormatters.recordingClock(segment.startTime))
                            .font(.body.monospacedDigit())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Correction")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextEditor(text: $draftText)
                            .frame(minHeight: 180)
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .disabled(isSaving)
                            .focused($isEditorFocused)
                            .accessibilityLabel("Transcript text")

                        Text("Saving a correction updates the transcript first, then refreshes the review from that corrected source when possible.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            TempDebugLog.append("Transcript sheet presented segment=\(segment.id)")
            isEditorFocused = true
        }
        .onDisappear {
            TempDebugLog.append("Transcript sheet disappeared segment=\(segment.id)")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                TempDebugLog.append("Transcript sheet cancel tapped segment=\(segment.id)")
                isEditorFocused = false
                onCancel()
            }
            .disabled(isSaving)

            Spacer()

            Text("Correct Transcript")
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Group {
                if isSaving {
                    ProgressView()
                        .accessibilityLabel("Saving correction")
                } else {
                    Button("Save") {
                        saveCorrection()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var isSaveDisabled: Bool {
        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDraft.isEmpty || trimmedDraft == segment.text
    }

    private func saveCorrection() {
        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        TempDebugLog.append("Transcript sheet save tapped segment=\(segment.id) chars=\(trimmedDraft.count)")
        isSaving = true
        isEditorFocused = false

        Task {
            let didSave = await onSave(trimmedDraft)
            await MainActor.run {
                if didSave {
                    TempDebugLog.append("Transcript sheet save succeeded segment=\(segment.id)")
                    onCancel()
                } else {
                    TempDebugLog.append("Transcript sheet save failed segment=\(segment.id)")
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    EditTranscriptSegmentSheet(
        segment: PreviewFixtures.sampleTranscriptSegments[1],
        onCancel: {},
        onSave: { _ in
        true
        }
    )
}

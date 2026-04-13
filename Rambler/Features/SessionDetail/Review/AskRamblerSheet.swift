import SwiftUI

struct AskRamblerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var prompt: String
    let state: AskRamblerState
    let sourceEvidence: SessionDetailViewModel.SourceEvidence?
    let savedMessage: String?
    let onSubmit: () -> Void
    let onQuickAction: (AskRamblerQuickAction) -> Void
    let onApply: (AskRamblerSaveDestination) -> Void
    let onJumpToSource: (() -> Void)?
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    promptComposer
                    quickActionsSection
                    answerSection
                }
                .padding()
            }
            .navigationTitle("Ask Rambler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onDisappear(perform: onReset)
        }
    }

    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask a question about this session.")
                .font(.headline)

            Text("Nothing is saved until you add it to Review.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Ask about this session", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            Button(action: onSubmit) {
                Label("Ask Rambler", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start With")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 120), spacing: 12),
                    GridItem(.flexible(minimum: 120), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(AskRamblerQuickAction.allCases) { action in
                    Button {
                        onQuickAction(action)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(action.title, systemImage: action.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(action.defaultPrompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        switch state {
        case .idle:
            ContentUnavailableView(
                "No Draft Yet",
                systemImage: "text.bubble",
                description: Text("Choose a starting point or ask something specific about this session.")
            )

        case .generating(let title):
            VStack(alignment: .leading, spacing: 12) {
                ProgressView()
                Text(title)
                    .font(.headline)
                Text("Drafting an answer from this session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .failed(let message):
            ContentUnavailableView(
                "Couldn’t Answer",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )

        case .ready(let response):
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(response.title)
                        .font(.headline)

                    Text(response.answer)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if let sourceEvidence {
                    SourceEvidencePreview(evidence: sourceEvidence)
                }

                ViewThatFits(in: .vertical) {
                    HStack(spacing: 12) {
                        primaryApplyButton(for: response)

                        saveMenu

                        if let onJumpToSource {
                            SourceLinkButton(action: onJumpToSource)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        primaryApplyButton(for: response)
                        saveMenu

                        if let onJumpToSource {
                            SourceLinkButton(action: onJumpToSource)
                        }
                    }
                }

                if let savedMessage {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Not saved until you add it to Review.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private func primaryApplyButton(for response: AskRamblerResponse) -> some View {
        if let destination = response.suggestedSaveDestination {
            Button {
                onApply(destination)
            } label: {
                Label(destination.title, systemImage: destination.systemImage)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var saveMenu: some View {
        Menu {
            ForEach(AskRamblerSaveDestination.allCases) { destination in
                Button {
                    onApply(destination)
                } label: {
                    Label(destination.title, systemImage: destination.systemImage)
                }
            }
        } label: {
            Label("Add to Review", systemImage: "square.and.arrow.down")
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    AskRamblerSheet(
        prompt: .constant("What decisions were made?"),
        state: .ready(
            AskRamblerResponse(
                title: "Decisions",
                prompt: "What decisions were made?",
                answer: "The team moved the photo shoot to Thursday morning and left one styling choice unresolved.",
                sourceSegmentIDs: [PreviewFixtures.sampleTranscriptSegments[1].id],
                suggestedSaveDestination: .decision
            )
        ),
        sourceEvidence: SessionDetailViewModel.SourceEvidence(
            timestamp: "00:12",
            accessibilityTimestamp: "12 seconds",
            excerpt: PreviewFixtures.sampleTranscriptSegments[1].text,
            additionalSourceCount: 0
        ),
        savedMessage: "Saved as a decision.",
        onSubmit: {},
        onQuickAction: { _ in },
        onApply: { _ in },
        onJumpToSource: {},
        onReset: {}
    )
}

import SwiftUI

struct SessionReviewView: View {
    var viewModel: SessionDetailViewModel
    let showTranscriptForItem: (SummaryItem) -> Void
    let presentAskRambler: () -> Void

    var body: some View {
        switch viewModel.summaryState {
        case .processing(let chunk, let total):
            VStack(spacing: 12) {
                ProgressView(value: Double(chunk), total: Double(total))
                Text("Preparing review \(chunk) of \(total)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

        case .checkingAvailability:
            ProgressView("Preparing review...")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)

        case .unavailable(let reason):
            ContentUnavailableView(
                "Review Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(reason)
            )

        case .failed(let error):
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Review Failed",
                    systemImage: "xmark.octagon",
                    description: Text(error)
                )

                Button("Try Again") {
                    Task { await viewModel.generateSummary() }
                }
                .buttonStyle(.bordered)
            }

        case .idle, .finished:
            if !viewModel.hasReviewContent {
                VStack(spacing: 24) {
                    ContentUnavailableView(
                        "No Review Yet",
                        systemImage: "text.document",
                        description: Text(viewModel.summaryEmptyStateMessage ?? "Generate a review from the transcript, or add items yourself.")
                    )

                    Button("Generate Review") {
                        Task { await viewModel.generateSummary() }
                    }
                    .buttonStyle(.borderedProminent)

                    toolsSection
                }
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    summaryCard
                    summarySection(title: SummaryItem.ItemType.overview.sectionTitle, items: viewModel.items(for: .overview))
                    summarySection(title: SummaryItem.ItemType.decision.sectionTitle, items: viewModel.items(for: .decision))
                    actionsSection(items: viewModel.items(for: .actionItem))
                    summarySection(title: SummaryItem.ItemType.openQuestion.sectionTitle, items: viewModel.items(for: .openQuestion))
                    toolsSection
                }
            }
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        if let reviewSummary = viewModel.normalizedReviewSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("Summary")
                    .font(.headline)

                Text(reviewSummary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tools")
                .font(.headline)

            Button(action: presentAskRambler) {
                Label("Ask Rambler", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            ViewThatFits(in: .vertical) {
                HStack(spacing: 12) {
                    addItemMenu
                    refreshButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    addItemMenu
                    refreshButton
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var addItemMenu: some View {
        Menu {
            ForEach(SummaryItem.ItemType.allCases, id: \.self) { type in
                Button(type.editorTitle, systemImage: type.systemImage) {
                    viewModel.beginCreatingItem(of: type)
                }
            }
        } label: {
            Label("Add Item", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .foregroundStyle(.primary)
        .accessibilityHint("Create a key point, decision, action item, or open question.")
    }

    private var refreshButton: some View {
        Button(action: viewModel.clearSummaryAndRegenerate) {
            Label("Refresh Review", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func summarySection(title: String, items: [SummaryItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: title, count: items.count)

                ForEach(items) { item in
                    SummaryRowView(item: item, sourceEvidence: viewModel.sourceEvidence(for: item)) {
                        showTranscriptForItem(item)
                    }
                    .contextMenu {
                        Button("Edit \(item.type.editorTitle)", systemImage: "pencil") {
                            viewModel.beginEditing(item)
                        }

                        Button("Delete", systemImage: "trash", role: .destructive) {
                            viewModel.deleteSummaryItem(item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionsSection(items: [SummaryItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: SummaryItem.ItemType.actionItem.sectionTitle, count: items.count)

                Text(viewModel.actionProgressLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(items) { item in
                    ActionRowView(item: item, sourceEvidence: viewModel.sourceEvidence(for: item)) { newStatus in
                        viewModel.updateActionStatus(for: item, to: newStatus)
                    } onEdit: {
                        viewModel.beginEditing(item)
                    } onDelete: {
                        viewModel.deleteSummaryItem(item)
                    } onJump: {
                        showTranscriptForItem(item)
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2.bold())

            Spacer()

            Text("\(count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count)")
    }
}

#Preview {
    ScrollView {
        SessionReviewView(
            viewModel: SessionDetailViewModel(recording: PreviewFixtures.recordingWithArtifacts()),
            showTranscriptForItem: { _ in },
            presentAskRambler: {}
        )
        .padding()
    }
}

import SwiftUI

struct ActionRowView: View {
    let item: SummaryItem
    let sourceEvidence: SessionDetailViewModel.SourceEvidence?
    let onStatusChange: (SummaryItem.ActionStatus) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onJump: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Menu {
                ForEach(SummaryItem.ActionStatus.allCases, id: \.self) { status in
                    Button(status.rawValue) { onStatusChange(status) }
                }
            } label: {
                Label(item.actionStatus?.rawValue ?? "To Do", systemImage: iconForStatus(item.actionStatus))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(colorForStatus(item.actionStatus).opacity(0.12), in: Capsule())
                    .foregroundStyle(colorForStatus(item.actionStatus))
            }
            .accessibilityLabel("Action status: \(item.actionStatus?.rawValue ?? "To Do")")
            .accessibilityHint("Double tap to change action status.")
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content)
                    .font(.body)
                    .foregroundStyle(item.actionStatus == .done ? .secondary : .primary)
                    .strikethrough(item.actionStatus == .done)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let sourceEvidence {
                    SourceEvidencePreview(evidence: sourceEvidence)
                }

                if item.isUserEdited || !item.sourceSegmentIDs.isEmpty {
                    SummaryItemAccessoryRow(
                        isEdited: item.isUserEdited,
                        onSourceTap: item.sourceSegmentIDs.isEmpty ? nil : onJump
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("Edit Action", systemImage: "pencil", action: onEdit)
            Button("Delete Action", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
    
    private func iconForStatus(_ status: SummaryItem.ActionStatus?) -> String {
        switch status {
        case .done: return "checkmark.circle.fill"
        case .inProgress: return "circle.dotted"
        case .todo, .none: return "circle"
        }
    }
    
    private func colorForStatus(_ status: SummaryItem.ActionStatus?) -> Color {
        switch status {
        case .done: return .green
        case .inProgress: return .blue
        case .todo, .none: return .secondary
        }
    }
}

#Preview {
    ActionRowView(
        item: PreviewFixtures.sampleSummaryItems[2],
        sourceEvidence: SessionDetailViewModel.SourceEvidence(
            timestamp: "00:26",
            accessibilityTimestamp: "26 seconds",
            excerpt: PreviewFixtures.sampleTranscriptSegments[2].text,
            additionalSourceCount: 0
        ),
        onStatusChange: { _ in },
        onEdit: {},
        onDelete: {},
        onJump: {}
    )
    .padding()
}

import SwiftUI

struct EditedBadgeView: View {
    var body: some View {
        Text("Edited")
            .font(.caption2)
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.12), in: Capsule())
            .accessibilityLabel("Edited by you")
    }
}

struct SourceLinkButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Source", systemImage: "quote.opening")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to source transcript")
        .accessibilityHint("Plays audio and highlights the supporting transcript.")
    }
}

struct SourceEvidencePreview: View {
    let evidence: SessionDetailViewModel.SourceEvidence

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(evidence.timestamp, systemImage: "quote.opening")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if evidence.additionalSourceCount > 0 {
                    Text("+\(evidence.additionalSourceCount) more")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }

            Text(evidence.excerpt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(evidence.accessibilityLabel)
    }
}

struct SummaryItemAccessoryRow: View {
    let isEdited: Bool
    var onSourceTap: (() -> Void)?

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                accessoryContent
            }

            VStack(alignment: .leading, spacing: 8) {
                accessoryContent
            }
        }
    }

    @ViewBuilder
    private var accessoryContent: some View {
        if isEdited {
            EditedBadgeView()
        }

        if let onSourceTap {
            SourceLinkButton(action: onSourceTap)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        EditedBadgeView()
        SourceLinkButton(action: {})
        SourceEvidencePreview(
            evidence: SessionDetailViewModel.SourceEvidence(
                timestamp: "00:12",
                accessibilityTimestamp: "12 seconds",
                excerpt: "Let's move the photo shoot to Thursday morning so the room can air out overnight.",
                additionalSourceCount: 1
            )
        )
        SummaryItemAccessoryRow(isEdited: true, onSourceTap: {})
    }
    .padding()
}

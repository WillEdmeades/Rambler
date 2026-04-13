import SwiftUI

struct SummaryRowView: View {
    let item: SummaryItem
    let sourceEvidence: SessionDetailViewModel.SourceEvidence?
    let onSourceTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 6, height: 6)
                .padding(.top, 8)
                .accessibilityHidden(true)
                
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let sourceEvidence {
                    SourceEvidencePreview(evidence: sourceEvidence)
                }

                if item.isUserEdited || !item.sourceSegmentIDs.isEmpty {
                    SummaryItemAccessoryRow(
                        isEdited: item.isUserEdited,
                        onSourceTap: item.sourceSegmentIDs.isEmpty ? nil : onSourceTap
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    SummaryRowView(
        item: PreviewFixtures.sampleSummaryItems[1],
        sourceEvidence: SessionDetailViewModel.SourceEvidence(
            timestamp: "00:12",
            accessibilityTimestamp: "12 seconds",
            excerpt: PreviewFixtures.sampleTranscriptSegments[1].text,
            additionalSourceCount: 0
        ),
        onSourceTap: {}
    )
    .padding()
}

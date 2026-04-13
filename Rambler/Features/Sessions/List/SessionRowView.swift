import SwiftUI

struct SessionRowView: View {
    var recording: Recording
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    if recording.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Pinned")
                    }
                    Text(recording.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Text(recording.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(RamblerFormatters.sessionDuration(recording.duration))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(RamblerFormatters.accessibilityDuration(recording.duration))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recording.isPinned ? "Pinned session, " : "")\(recording.title), recorded \(recording.timestamp.formatted(date: .abbreviated, time: .shortened)), duration \(RamblerFormatters.accessibilityDuration(recording.duration))")
    }
}

#Preview {
    SessionRowView(recording: PreviewFixtures.sampleRecording)
        .padding()
}

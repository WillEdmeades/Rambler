import SwiftUI

struct SessionTranscriptView: View {
    var viewModel: SessionDetailViewModel
    @Binding var editingSegment: TranscriptSegment?

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.searchText.isEmpty, !viewModel.searchMatches.isEmpty {
                HStack {
                    Text("\(viewModel.currentSearchIndex + 1) of \(viewModel.searchMatches.count) matches")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: viewModel.previousMatch) {
                        Image(systemName: "chevron.up")
                    }
                    .padding(.horizontal, 8)
                    .accessibilityLabel("Previous Match")

                    Button(action: viewModel.nextMatch) {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Next Match")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }

            transcriptUpdateBanner

            if !viewModel.bookmarkStops.isEmpty {
                bookmarkRail
            }

            if viewModel.segments.isEmpty {
                Spacer()
                Text("No transcript yet.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.segments) { segment in
                                transcriptRow(for: segment)
                                    .padding(.horizontal)
                                    .id(segment.id)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.currentSearchIndex) { _, newIndex in
                        guard viewModel.searchMatches.indices.contains(newIndex) else { return }
                        withAnimation {
                            proxy.scrollTo(viewModel.searchMatches[newIndex], anchor: .top)
                        }
                    }
                    .onChange(of: viewModel.scrollTargetID) { _, targetID in
                        guard let id = targetID else { return }
                        Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    private func transcriptRow(for segment: TranscriptSegment) -> some View {
        let isActive = viewModel.currentTime >= segment.startTime && viewModel.currentTime < segment.endTime
        let isMatch = !viewModel.searchText.isEmpty && segment.text.localizedCaseInsensitiveContains(viewModel.searchText)
        let hasBookmark = viewModel.recording.bookmarks.contains { $0 >= segment.startTime && $0 < segment.endTime }

        return HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.jumpTo(segment: segment)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(RamblerFormatters.recordingClock(segment.startTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(isActive ? .blue : .secondary)

                        if hasBookmark {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(width: 45, alignment: .topLeading)

                    Text(segment.text)
                        .font(.body)
                        .foregroundStyle(isActive ? .primary : .secondary)
                        .bold(isMatch)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(RamblerFormatters.accessibilityDuration(segment.startTime)), \(segment.text)\(hasBookmark ? ", bookmarked" : "")")
            .accessibilityHint("Double tap to play audio from this point.")

            Button {
                editingSegment = segment
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Correct transcript at \(RamblerFormatters.accessibilityDuration(segment.startTime))")
            .accessibilityHint("Edits this transcript line and refreshes review if needed.")
        }
    }

    @ViewBuilder
    private var transcriptUpdateBanner: some View {
        switch viewModel.transcriptUpdateState {
        case .idle:
            EmptyView()
        case .saving:
            transcriptStatusCard(
                message: "Saving transcript change...",
                systemImage: "square.and.pencil",
                color: .secondary,
                showsDismissButton: false
            )
        case .refreshingReview:
            transcriptStatusCard(
                message: "Updating review from the edited transcript...",
                systemImage: "arrow.clockwise",
                color: .secondary,
                showsDismissButton: false
            )
        case .saved(let message):
            transcriptStatusCard(
                message: message,
                systemImage: "checkmark.circle.fill",
                color: .green,
                showsDismissButton: true
            )
        case .failed(let message):
            transcriptStatusCard(
                message: message,
                systemImage: "exclamationmark.triangle.fill",
                color: .orange,
                showsDismissButton: true
            )
        }
    }

    private func transcriptStatusCard(
        message: String,
        systemImage: String,
        color: Color,
        showsDismissButton: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsDismissButton {
                Button(action: viewModel.dismissTranscriptUpdateMessage) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss status")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var bookmarkRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bookmarks")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.bookmarkStops.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.bookmarkStops) { bookmark in
                        Button {
                            viewModel.jumpToBookmark(bookmark)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(bookmark.timeLabel, systemImage: "bookmark.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)

                                Text(bookmark.previewText)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(width: 220, alignment: .leading)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Bookmark at \(bookmark.accessibilityTimeLabel). \(bookmark.previewText)")
                        .accessibilityHint("Double tap to play from this bookmarked moment.")
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }
}

#Preview {
    SessionTranscriptView(
        viewModel: SessionDetailViewModel(recording: PreviewFixtures.recordingWithArtifacts()),
        editingSegment: .constant(nil)
    )
}

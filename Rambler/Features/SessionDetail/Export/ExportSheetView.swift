import SwiftUI
import UIKit

struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let recording: Recording
    let segments: [TranscriptSegment]
    let reviewSummary: String?
    let summaries: [SummaryItem]
    
    @State private var shareURLs: [URL]?
    @State private var isSharing = false
    @State private var exportErrorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Full Session"), footer: Text("Includes the review summary, structured notes, and the timestamped transcript.")) {
                    Button("Markdown Document (.md)") {
                        export {
                            [try ExportService.shared.generateMarkdown(
                                for: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries
                            )]
                        }
                    }
                    Button("Plain Text (.txt)") {
                        export {
                            [try ExportService.shared.generatePlainText(
                                for: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries
                            )]
                        }
                    }
                    Button("Structured Object (.json)") {
                        export {
                            [try ExportService.shared.generateJSON(
                                for: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries
                            )]
                        }
                    }
                }

                Section(header: Text("Focused Notes"), footer: Text("Exports only the distilled notes you may want to share after review.")) {
                    Button("Summary Notes (.md)") {
                        export {
                            [try ExportService.shared.generateMarkdown(
                                for: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries,
                                scope: .summaryNotes
                            )]
                        }
                    }
                    Button("Summary Notes (.txt)") {
                        export {
                            [try ExportService.shared.generatePlainText(
                                for: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries,
                                scope: .summaryNotes
                            )]
                        }
                    }
                    Button("Action List (.md)") {
                        export {
                            [try ExportService.shared.generateMarkdown(
                                for: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries,
                                scope: .actionsOnly
                            )]
                        }
                    }
                    Button("Action List (.txt)") {
                        export {
                            [try ExportService.shared.generatePlainText(
                                for: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries,
                                scope: .actionsOnly
                            )]
                        }
                    }
                }
                
                Section("Media") {
                    Button("Audio Track (.m4a)") {
                        if let url = recording.audioFileURL {
                            export {
                                [try ExportService.shared.duplicateAudio(from: url, title: recording.title)]
                            }
                        }
                    }
                    .disabled(recording.audioFileURL == nil)
                }
                
                Section(header: Text("Full Package"), footer: Text("Exports Markdown, JSON, and audio together.")) {
                    Button("Complete Project Files") {
                        export {
                            try ExportService.shared.generateFullPackage(
                                recording: recording,
                                segments: segments,
                                reviewSummary: reviewSummary,
                                summaries: summaries
                            )
                        }
                    }
                }
            }
            .navigationTitle("Export Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let urls = shareURLs {
                    shareDestination(urls: urls)
                }
            }
            .alert("Export Failed", isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    exportErrorMessage = nil
                }
            } message: {
                Text(exportErrorMessage ?? "The export couldn't be created.")
            }
        }
    }

    @ViewBuilder
    private func shareDestination(urls: [URL]) -> some View {
        ShareSheet(activityItems: urls)
            .presentationDetents([.medium, .large])
    }

    private func export(_ action: () throws -> [URL]) {
        do {
            shareURLs = try action()
            isSharing = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportSheetView(
        recording: PreviewFixtures.sampleRecording,
        segments: PreviewFixtures.sampleTranscriptSegments,
        reviewSummary: PreviewFixtures.sampleReviewSummary,
        summaries: PreviewFixtures.sampleSummaryItems
    )
}

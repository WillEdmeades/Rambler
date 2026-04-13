import SwiftUI

struct PreflightView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PreflightViewModel()
    var onStart: ((CaptureConfiguration) -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session Title", text: $viewModel.sessionTitle)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                    
                    Picker("Language", selection: $viewModel.selectedLocale) {
                        ForEach(viewModel.availableLocales) { locale in
                            Text(locale.displayName).tag(locale.identifier)
                        }
                    }
                } header: {
                    Text("Details")
                }
                
                Section {
                    Toggle(isOn: $viewModel.hasConsent) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Participant Consent")
                                .font(.headline)
                            Text("I confirm all participants have explicitly consented to being recorded and transcribed locally.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Participant Consent. I confirm all participants have explicitly consented to being recorded and transcribed locally.")
                    .accessibilityHint("Required before recording can begin.")
                } header: {
                    Text("Privacy & Legal")
                }
                
                Section {
                    ReadinessRow(title: "Microphone Access", isReady: viewModel.isMicrophoneReady)
                    ReadinessRow(title: "Speech Recognizer", isReady: viewModel.isSpeechSupportReady)
                    ReadinessRow(title: "On-Device Assets", isReady: viewModel.areSpeechAssetsDownloaded)
                    ReadinessRow(title: "Summarization Models", isReady: viewModel.isSummaryModelAvailable)
                } header: {
                    Text("System Checks")
                } footer: {
                    Text(viewModel.speechStatusMessage)
                }
            }
            .navigationTitle("New Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Recording") {
                        let configuration = CaptureConfiguration(
                            title: viewModel.sessionTitle,
                            localeIdentifier: viewModel.selectedLocale
                        )
                        dismiss()
                        onStart?(configuration)
                    }
                    .accessibilityLabel("Start Recording")
                    .disabled(!viewModel.canStartRecording)
                }
            }
        }
        .interactiveDismissDisabled(true)
        .task(id: viewModel.selectedLocale) {
            await viewModel.performHardwareChecks()
        }
    }
}

private struct ReadinessRow: View {
    let title: String
    let isReady: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isReady ? .green : .orange)
                .accessibilityLabel(isReady ? "Ready" : "Pending")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isReady ? "Ready" : "Pending")")
    }
}

#Preview {
    PreflightView()
}

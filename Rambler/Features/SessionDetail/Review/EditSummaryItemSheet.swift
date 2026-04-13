import SwiftUI

struct EditSummaryItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: SummaryItem
    var onSave: (SummaryItem) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(item.type.editorTitle)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Type")
                }

                Section {
                    TextEditor(text: $item.content)
                        .frame(minHeight: 100)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Summary item content")
                } header: {
                    Text("Content")
                } footer: {
                    Text("Keep the note short, specific, and grounded in the conversation.")
                }
                
                if item.type == .actionItem {
                    Section {
                        Picker("Status", selection: Binding(
                            get: { item.actionStatus ?? .todo },
                            set: { item.actionStatus = $0 }
                        )) {
                            ForEach(SummaryItem.ActionStatus.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(status)
                            }
                        }
                    } header: {
                        Text("Status")
                    }
                }
                
                if !item.sourceSegmentIDs.isEmpty {
                    Section {
                        Label("Linked to transcript evidence", systemImage: "quote.opening")
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Edited items are anchored to the original transcript timestamp and will not be overwritten by future summaries.")
                    }
                } else {
                    Section {
                        Label("Manual note", systemImage: "square.and.pencil")
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("Manual notes sit alongside transcript-linked items so you can keep reviewing even when AI output is limited.")
                    }
                }
            }
            .navigationTitle(item.content.isEmpty ? "New \(item.type.editorTitle)" : "Edit \(item.type.editorTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var finalItem = item
                        finalItem.content = finalItem.content.trimmingCharacters(in: .whitespacesAndNewlines)
                        finalItem.isUserEdited = true
                        onSave(finalItem)
                        dismiss()
                    }
                    .disabled(item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    EditSummaryItemSheet(
        item: PreviewFixtures.sampleSummaryItems[2],
        onSave: { _ in }
    )
}

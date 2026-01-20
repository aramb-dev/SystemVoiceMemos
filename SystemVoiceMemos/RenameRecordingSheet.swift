//
//  RenameRecordingSheet.swift
//  SystemVoiceMemos
//

import SwiftUI

struct RenameRecordingSheet: View {
    let recordingTitle: String
    @Binding var newTitle: String
    let onRename: (String) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Recording")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current: \(recordingTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("New Name", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit {
                        if !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onRename(newTitle)
                        }
                    }
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Rename") {
                    onRename(newTitle)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450)
        .onAppear {
            isFocused = true
        }
    }
}

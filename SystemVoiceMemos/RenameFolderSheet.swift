//
//  RenameFolderSheet.swift
//  SystemVoiceMemos
//

import SwiftUI

struct RenameFolderSheet: View {
    let folderName: String
    @Binding var newName: String
    let onRename: (String) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Folder")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current name: \(folderName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("New Folder Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit {
                        if !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onRename(newName)
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
                    onRename(newName)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            newName = folderName
            isFocused = true
        }
    }
}

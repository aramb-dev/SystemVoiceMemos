//
//  MoveToFolderSheet.swift
//  SystemVoiceMemos
//

import SwiftUI
import SwiftData

struct MoveToFolderSheet: View {
    let folders: [FolderEntity]
    @Binding var folderName: String
    let onMove: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Move to Folder")
                    .font(.headline)
                Text("Enter a folder name or select an existing one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                TextField("Folder Name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        onMove(folderName)
                    }

                if !folders.isEmpty {
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(folders) { folder in
                                Button {
                                    folderName = folder.name
                                    onMove(folder.name)
                                } label: {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundStyle(.blue)
                                        Text(folder.name)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(folderName == folder.name ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            HStack {
                Button("Clear Folder", role: .destructive) {
                    onMove("")
                }
                .disabled(folderName.isEmpty)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Move") {
                    onMove(folderName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

//
//  CreateFolderSheet.swift
//  SystemVoiceMemos
//

import SwiftUI

struct CreateFolderSheet: View {
    @Binding var folderName: String
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Folder")
                .font(.title2)
                .fontWeight(.semibold)
            
            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    if !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onCreate(folderName)
                    }
                }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create") {
                    onCreate(folderName)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            isFocused = true
        }
    }
}

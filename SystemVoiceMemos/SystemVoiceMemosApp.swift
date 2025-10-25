//
//  SystemVoiceMemosApp.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//

import SwiftUI
import SwiftData

@main
struct SystemVoiceMemosApp: App {
    @StateObject private var playbackManager = PlaybackManager()
    @State private var isShowingAboutWindow = false

    var body: some Scene {
        WindowGroup {
            ContentView()   // works because we added init() {}
                .environmentObject(playbackManager)
        }
        .modelContainer(for: RecordingEntity.self)
        .commands {
            CommandMenu("Playback") {
                Button(playbackManager.isPlaying ? "Pause" : "Play") {
                    playbackManager.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!playbackManager.hasSelection)

                Button("Play Selection") {
                    playbackManager.playSelected()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!playbackManager.canPlaySelection)

                Divider()

                Button("Skip Back 15s") {
                    playbackManager.skip(by: -15)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.option])
                .disabled(!playbackManager.hasActivePlayer)

                Button("Skip Forward 15s") {
                    playbackManager.skip(by: 15)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.option])
                .disabled(!playbackManager.hasActivePlayer)
            }
            
            CommandMenu("Help") {
                Button("About System Voice Memos") {
                    showAboutWindow()
                }
            }
        }
        .sheet(isPresented: $isShowingAboutWindow) {
            AboutView()
        }
    }
    
    private func showAboutWindow() {
        isShowingAboutWindow = true
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            // App Name
            Text("System Voice Memos")
                .font(.title)
                .fontWeight(.bold)
            
            // Version (you can update this as needed)
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Open Source Information
            VStack(spacing: 12) {
                Text("This app is entirely open source")
                    .font(.headline)
                
                Text("Made by aramb-dev")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // GitHub Link
                Link("github.com/aramb-dev", destination: URL(string: "https://github.com/aramb-dev")!)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
            )
            
            // Close Button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 400, height: 350)
    }
}

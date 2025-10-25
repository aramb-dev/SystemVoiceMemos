//
//  SystemVoiceMemosApp.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct SystemVoiceMemosApp: App {
    @StateObject private var playbackManager = PlaybackManager()

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
    }
    
    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "System Voice Memos"
        alert.informativeText = """
        Version 1.0.0
        
        This app is entirely open source
        Made by aramb-dev
        
        GitHub: github.com/aramb-dev
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Visit GitHub")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/aramb-dev") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

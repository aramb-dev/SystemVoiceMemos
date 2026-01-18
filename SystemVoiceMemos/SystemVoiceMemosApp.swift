//
//  SystemVoiceMemosApp.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//

import SwiftUI
import SwiftData
import AppKit

extension Notification.Name {
    static let showOnboarding = Notification.Name("showOnboarding")
}

@main
struct SystemVoiceMemosApp: App {
    @AppStorage(AppConstants.UserDefaultsKeys.hasCompletedOnboarding) var hasCompletedOnboarding = false
    @StateObject private var playbackManager = PlaybackManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(playbackManager)
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                // Set main window identifier for WindowAnimator
                if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
                    window.identifier = NSUserInterfaceItemIdentifier("main_window")
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
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
                Button("Show Welcome Guide") {
                    hasCompletedOnboarding = false
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Button("About System Voice Memos") {
                    showAboutWindow()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: [.command])
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

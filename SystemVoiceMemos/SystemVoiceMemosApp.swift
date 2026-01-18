//
//  SystemVoiceMemosApp.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//

import SwiftUI
import SwiftData
import AppKit
import Sparkle

extension Notification.Name {
    static let showOnboarding = Notification.Name("showOnboarding")
    static let startRecording = Notification.Name("startRecording")
    static let stopRecording = Notification.Name("stopRecording")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let clearDeletedRecordings = Notification.Name("clearDeletedRecordings")
    static let checkForUpdates = Notification.Name("checkForUpdates")
}

@main
struct SystemVoiceMemosApp: App {
    @AppStorage(AppConstants.UserDefaultsKeys.hasCompletedOnboarding) var hasCompletedOnboarding = false
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var updaterManager = UpdaterManager()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(playbackManager)
                .onAppear {
                    // Set main window identifier for WindowAnimator
                    if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
                        window.identifier = NSUserInterfaceItemIdentifier("main_window")
                    }
                    
                    // Show onboarding window if not completed
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .frame(width: 800, height: 600)
                        .interactiveDismissDisabled(!hasCompletedOnboarding)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .modelContainer(for: [RecordingEntity.self, FolderEntity.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove "New Window" command to prevent multiple windows
            }
            
            CommandMenu("Recording") {
                Button("New Recording") {
                    // This will trigger via notification
                    NotificationCenter.default.post(name: .startRecording, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Stop Recording") {
                    NotificationCenter.default.post(name: .stopRecording, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            
            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }
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
                Button("Check for Updates…") {
                    updaterManager.checkForUpdates()
                }
                
                Divider()
                
                Button("Show Welcome Guide") {
                    showOnboarding = true
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
        Version 1.1.0
        
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

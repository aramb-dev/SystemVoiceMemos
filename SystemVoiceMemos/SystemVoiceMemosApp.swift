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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !AppState.shared.isRecording
    }
}

@main
struct SystemVoiceMemosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(AppConstants.UserDefaultsKeys.hasCompletedOnboarding) var hasCompletedOnboarding = false
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var updaterManager = UpdaterManager()
    @State private var showOnboarding = false

    private var appState: AppState { AppState.shared }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(playbackManager)
                .onAppear {
                    if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
                        window.identifier = NSUserInterfaceItemIdentifier("main_window")
                    }

                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .frame(width: 800, height: 600)
                        .interactiveDismissDisabled(!hasCompletedOnboarding)
                }
                .onChange(of: appState.checkForUpdatesTrigger) { _, _ in
                    updaterManager.checkForUpdates()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .modelContainer(for: [RecordingEntity.self, FolderEntity.self])
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Recording") {
                Button("New Recording") {
                    AppState.shared.requestStartRecording()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Stop Recording") {
                    AppState.shared.requestStopRecording()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    AppState.shared.requestToggleSidebar()
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
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        alert.informativeText = """
        Version \(version) (\(build))

        This app is entirely open source
        Made by aramb-dev

        GitHub: github.com/aramb-dev
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Visit GitHub")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/aramb-dev/SystemVoiceMemos") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

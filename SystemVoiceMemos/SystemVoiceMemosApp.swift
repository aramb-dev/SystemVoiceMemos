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
            }

            CommandGroup(replacing: .appInfo) {
                Button("About System Voice Memos") {
                    AboutWindowController.shared.show()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Check for Updates…") {
                    updaterManager.checkForUpdates()
                }

                Button("Settings…") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

// MARK: - About Window

private struct AboutView: View {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    var body: some View {
        VStack(spacing: 16) {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            Text("System Voice Memos")
                .font(.system(size: 20, weight: .bold))

            Text("Version \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 24)

            VStack(spacing: 6) {
                Text("Capture system audio as voice memos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Made by aramb-dev")
                    .font(.subheadline)

                Text("This app is entirely open source")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("View on GitHub") {
                if let url = URL(string: "https://github.com/aramb-dev/SystemVoiceMemos") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
        }
        .padding(32)
        .frame(width: 300)
    }
}

@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "About System Voice Memos"
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

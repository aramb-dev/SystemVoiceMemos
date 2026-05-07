//
//  SystemVoiceMemosApp.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//

import AppKit
import Sparkle
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        !AppState.shared.isRecording
    }
}

@main
struct SystemVoiceMemosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(AppConstants.UserDefaultsKeys.hasCompletedOnboarding) var hasCompletedOnboarding = false
    @AppStorage(AppConstants.UserDefaultsKeys.lastSeenWhatsNewVersion) private var lastSeenWhatsNewVersion = ""
    @StateObject private var playbackManager = PlaybackManager()
    @StateObject private var updaterManager = UpdaterManager()
    @State private var showOnboarding = false
    @State private var showWhatsNew = false

    private var appState: AppState {
        AppState.shared
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.10.2"
    }

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
                    } else {
                        showWhatsNewIfNeeded()
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .frame(width: 800, height: 600)
                        .interactiveDismissDisabled(!hasCompletedOnboarding)
                }
                .sheet(isPresented: $showWhatsNew) {
                    WhatsNewView(version: currentVersion) {
                        lastSeenWhatsNewVersion = currentVersion
                        showWhatsNew = false
                    }
                    .frame(width: 560, height: 520)
                }
                .onChange(of: hasCompletedOnboarding) { _, completed in
                    if completed {
                        showWhatsNewIfNeeded()
                    }
                }
                .onChange(of: appState.checkForUpdatesTrigger) { _, _ in
                    updaterManager.checkForUpdates()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .modelContainer(for: [RecordingEntity.self, FolderEntity.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(appState.isRecording ? "Stop Recording" : "New Recording") {
                    if appState.isRecording {
                        AppState.shared.requestStopRecording()
                    } else {
                        AppState.shared.requestStartRecording()
                    }
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Delete Recording") {
                    AppState.shared.requestDeleteRecording()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!appState.hasSelectedRecording)

                Divider()

                Button("Show in Finder") {
                    AppState.shared.requestRevealRecording()
                }
                .disabled(!appState.hasSelectedRecording)

                Button("Open in QuickTime Player") {
                    AppState.shared.requestOpenInQuickTime()
                }
                .disabled(!appState.hasSelectedRecording)
            }

            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    AppState.shared.requestToggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                Button("Show Main Window") {
                    AppState.shared.requestShowMainWindow()
                }

                Button("Show Recording Toolbar") {
                    AppState.shared.requestShowRecordingToolbar()
                }
                .disabled(!appState.isRecording)
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

            CommandGroup(after: .help) {
                Button("What’s New") {
                    showWhatsNew = true
                }

                Divider()

                // Existing onboarding - stays as separate entry
                Button("Show Welcome Guide") {
                    showOnboarding = true
                }
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

    private func showWhatsNewIfNeeded() {
        guard hasCompletedOnboarding, lastSeenWhatsNewVersion != currentVersion else { return }
        showWhatsNew = true
    }
}

// MARK: - What's New

private struct WhatsNewView: View {
    let version: String
    let onContinue: () -> Void

    private var releaseTitle: String {
        "What’s New in \(version)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    VStack(alignment: .leading, spacing: 20) {
                        WhatsNewFeatureRow(
                            icon: "waveform",
                            tint: .accentColor,
                            title: "System Audio Without Screen Recording",
                            description: "The 0.10.1 Core Audio tap recorder captures system audio directly on macOS 14.2 and later, without showing the screen-sharing UI or needing Screen Recording permission."
                        )

                        WhatsNewFeatureRow(
                            icon: "shield.checkered",
                            tint: .green,
                            title: "Safer Audio Capture",
                            description: "The Core Audio path now handles mic permission errors, unavailable devices, callback thread safety, older macOS availability, mic-track finalization, and waveform edge cases more reliably."
                        )

                        WhatsNewFeatureRow(
                            icon: "mic.badge.plus",
                            tint: .red,
                            title: "Mic Tracks, Playback, and Export",
                            description: "Record microphone audio as its own track, then listen to system audio, mic audio, or both together, with export options for mixed or separate files."
                        )

                        WhatsNewFeatureRow(
                            icon: "rectangle.on.rectangle",
                            tint: .blue,
                            title: "Recording Toolbar Controls",
                            description: "Customize the floating recording toolbar, restore it from the View or menu bar controls, and choose how it behaves when the main window is minimized or reopened."
                        )

                        WhatsNewFeatureRow(
                            icon: "sparkles",
                            tint: .purple,
                            title: "Cleaner Recording UI",
                            description: "No recording can now be selected cleanly, the empty detail view uses a waveform treatment, and the floating toolbar has softer edges with less visual artifacting."
                        )
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }

            Divider()

            HStack {
                Spacer()
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "app.badge")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Color.accentColor)

            Text(releaseTitle)
                .font(.largeTitle.bold())

            Text("Includes the 0.10.1 Core Audio tap work plus new track controls, toolbar settings, and interface polish.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WhatsNewFeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

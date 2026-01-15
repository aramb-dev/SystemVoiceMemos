import SwiftUI
import AppKit

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable {
    case general
    case recording

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .recording: return "waveform"
        }
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingView(rootView: SettingsRootView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

// MARK: - Settings Root View

struct SettingsRootView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Segmented tab bar
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Label(tab.displayName, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Content area
            ScrollView {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .recording:
                    RecordingSettingsView()
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 520, minHeight: 400)
    }
}

// MARK: - General Settings View

private struct GeneralSettingsView: View {
    @AppStorage(AppConstants.UserDefaultsKeys.hideFromScreenSharing) private var hideFromScreenSharing = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)

            Toggle(isOn: $hideFromScreenSharing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hide while screen sharing")
                        .font(.headline)
                    Text("Exclude System Voice Memos windows from screen sharing and screen recording.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording Settings View

private struct RecordingSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recording")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Recording settings will be added here.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

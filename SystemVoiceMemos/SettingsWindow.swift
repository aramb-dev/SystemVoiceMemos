import SwiftUI
import AppKit

// Manages a single Settings window instance and shows it on demand.
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
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

struct SettingsRootView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }

            PlaceholderSettingsView(title: "Advanced")
                .tabItem {
                    Label("Advanced", systemImage: "gearshape")
                }
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}

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
    }
}

private struct PlaceholderSettingsView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No settings yet")
                .font(.headline)
            Text("We'll add more options to \(title) soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI
import AppKit

// MARK: - Settings Tab View Controllers

private class GeneralSettingsViewController: NSViewController {
    override func loadView() {
        view = NSHostingView(rootView: GeneralSettingsView())
    }
}

private class RecordingSettingsViewController: NSViewController {
    override func loadView() {
        view = NSHostingView(rootView: RecordingSettingsView())
    }
}

// MARK: - SwiftUI Views

struct GeneralSettingsView: View {
    @AppStorage("hideFromScreenSharing") private var hideFromScreenSharing = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

struct RecordingSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recording settings will be added here.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toolbar Tab View Controller

private final class SettingsToolbarTabViewController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // This creates the Finder/System Preferences-style toolbar tabs
        tabStyle = .toolbar
        transitionOptions = .crossfade

        // Add panes
        addTab(title: "General", symbol: "slider.horizontal.3", controller: GeneralSettingsViewController())
        addTab(title: "Recording", symbol: "waveform", controller: RecordingSettingsViewController())
    }

    private func addTab(title: String, symbol: String, controller: NSViewController) {
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        addTabViewItem(item)
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let tabViewController = SettingsToolbarTabViewController()

        let window = NSWindow()
        window.contentViewController = tabViewController
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 400))

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

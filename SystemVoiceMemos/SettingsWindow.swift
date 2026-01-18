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

private class UpdatesSettingsViewController: NSViewController {
    override func loadView() {
        view = NSHostingView(rootView: UpdatesSettingsView())
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

struct UpdatesSettingsView: View {
    @AppStorage("updateCheckInterval") private var updateCheckInterval = 86400
    @AppStorage("automaticUpdateChecks") private var automaticUpdateChecks = true
    
    var body: some View {
        Form {
            Section("Automatic Updates") {
                Toggle(isOn: $automaticUpdateChecks) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check for updates automatically")
                            .font(.headline)
                        Text("System Voice Memos will periodically check for new versions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                
                if automaticUpdateChecks {
                    Picker("Check for updates", selection: $updateCheckInterval) {
                        Text("Every hour").tag(3600)
                        Text("Every 6 hours").tag(21600)
                        Text("Every 12 hours").tag(43200)
                        Text("Daily").tag(86400)
                        Text("Weekly").tag(604800)
                    }
                    .pickerStyle(.menu)
                    .disabled(!automaticUpdateChecks)
                }
            }
            
            Section("Manual Check") {
                Button("Check for Updates Now") {
                    checkForUpdatesNow()
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func checkForUpdatesNow() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }
}

struct RecordingSettingsView: View {
    @AppStorage("recordingsLocation") private var recordingsLocation = ""
    @AppStorage("audioQuality") private var audioQuality = "high"
    @AppStorage("locationBasedNaming") private var locationBasedNaming = false
    @AppStorage("autoDeleteAfterDays") private var autoDeleteAfterDays = 30
    @State private var showingLocationPicker = false
    
    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recordings Location")
                            .font(.headline)
                        Text(recordingsLocationDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Choose...") {
                        chooseRecordingsLocation()
                    }
                }
                
                Toggle(isOn: $locationBasedNaming) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location-based Naming")
                            .font(.headline)
                        Text("Include device location in recording names when available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            
            Section("Quality") {
                Picker("Audio Quality", selection: $audioQuality) {
                    Text("Low (64 kbps)").tag("low")
                    Text("Medium (128 kbps)").tag("medium")
                    Text("High (192 kbps)").tag("high")
                    Text("Maximum (320 kbps)").tag("maximum")
                }
                .pickerStyle(.menu)
            }
            
            Section("Cleanup") {
                HStack {
                    Text("Auto-delete recordings after")
                    TextField("Days", value: $autoDeleteAfterDays, format: .number)
                        .frame(width: 60)
                    Text("days")
                    Spacer()
                }
                
                Button("Clear All Deleted Recordings") {
                    clearDeletedRecordings()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var recordingsLocationDisplay: String {
        if recordingsLocation.isEmpty {
            return "Default (~/Documents/System Voice Memos)"
        }
        return recordingsLocation
    }
    
    private func chooseRecordingsLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to save recordings"
        
        if panel.runModal() == .OK, let url = panel.url {
            recordingsLocation = url.path
        }
    }
    
    private func clearDeletedRecordings() {
        let alert = NSAlert()
        alert.messageText = "Clear All Deleted Recordings"
        alert.informativeText = "This will permanently delete all recordings in the trash. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NotificationCenter.default.post(name: .clearDeletedRecordings, object: nil)
        }
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
        addTab(title: "Updates", symbol: "arrow.down.circle", controller: UpdatesSettingsViewController())
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

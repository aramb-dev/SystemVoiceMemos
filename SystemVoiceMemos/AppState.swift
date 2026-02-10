//
//  AppState.swift
//  SystemVoiceMemos
//
//  Shared observable state replacing NotificationCenter for cross-view events.
//  Views observe trigger properties via .onChange(of:) for type-safe signalling.
//

import Foundation
import AppKit

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    // One-shot event triggers — views observe via .onChange(of:)
    private(set) var startRecordingTrigger = 0
    private(set) var stopRecordingTrigger = 0
    private(set) var toggleSidebarTrigger = 0
    private(set) var clearDeletedRecordingsTrigger = 0
    private(set) var checkForUpdatesTrigger = 0

    /// Whether a recording is currently active (mirrors RecordingManager.isRecording)
    var isRecording = false {
        didSet { updateStatusItem() }
    }

    // MARK: - Menu Bar Status Item

    private var statusItem: NSStatusItem?
    private let menuActions = AppStateMenuActions()

    func requestStartRecording() { startRecordingTrigger &+= 1 }
    func requestStopRecording() { stopRecordingTrigger &+= 1 }
    func requestToggleSidebar() { toggleSidebarTrigger &+= 1 }
    func requestClearDeletedRecordings() { clearDeletedRecordingsTrigger &+= 1 }
    func requestCheckForUpdates() { checkForUpdatesTrigger &+= 1 }

    private func updateStatusItem() {
        if isRecording {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            }
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Recording")
                button.image?.isTemplate = true
                button.appearsDisabled = false
            }
            let menu = NSMenu()
            menu.addItem(withTitle: "Recording in progress…", action: nil, keyEquivalent: "")
            menu.addItem(.separator())
            let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(AppStateMenuActions.stopRecording), keyEquivalent: "")
            stopItem.target = menuActions
            menu.addItem(stopItem)
            menu.addItem(.separator())
            let showItem = NSMenuItem(title: "Show Window", action: #selector(AppStateMenuActions.showMainWindow), keyEquivalent: "")
            showItem.target = menuActions
            menu.addItem(showItem)
            statusItem?.menu = menu
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    private init() {}
}

/// Target for menu bar status item actions
@objc final class AppStateMenuActions: NSObject {
    @MainActor @objc func stopRecording() {
        AppState.shared.requestStopRecording()
    }

    @MainActor @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == "main_window" {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}

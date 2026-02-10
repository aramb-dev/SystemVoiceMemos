//
//  AppState.swift
//  SystemVoiceMemos
//
//  Shared observable state replacing NotificationCenter for cross-view events.
//  Views observe trigger properties via .onChange(of:) for type-safe signalling.
//

import Foundation

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

    func requestStartRecording() { startRecordingTrigger &+= 1 }
    func requestStopRecording() { stopRecordingTrigger &+= 1 }
    func requestToggleSidebar() { toggleSidebarTrigger &+= 1 }
    func requestClearDeletedRecordings() { clearDeletedRecordingsTrigger &+= 1 }
    func requestCheckForUpdates() { checkForUpdatesTrigger &+= 1 }

    private init() {}
}

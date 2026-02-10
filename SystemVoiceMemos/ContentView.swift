//
//  ContentView.swift
//  SystemVoiceMemos
//
//  Main application view that manages recordings, folders, and playback.
//  Implements a three-column layout with sidebar, recordings list, and detail panel.
//

import SwiftUI
import AppKit
import SwiftData
import AVFoundation

struct ContentView: View {
    // MARK: - Environment & Data

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playbackManager: PlaybackManager

    @Query(sort: \RecordingEntity.createdAt, order: .reverse)
    private var recordings: [RecordingEntity]

    @Query(sort: \FolderEntity.sortOrder)
    private var folders: [FolderEntity]

    // MARK: - View Model & Preferences

    @State private var vm = ContentViewModel()

    @AppStorage(AppConstants.UserDefaultsKeys.hideFromScreenSharing)
    private var hideFromScreenSharing = true

    @State private var sharePresenter = RecordingSharePresenter()

    private var appState: AppState { AppState.shared }

    // MARK: - Constants

    private let sidebarWidth: CGFloat = 220

    // MARK: - Convenience Accessors

    private var filteredRecordings: [RecordingEntity] {
        vm.filteredRecordings(from: recordings)
    }

    private var selectedRecording: RecordingEntity? {
        vm.selectedRecording(from: recordings)
    }

    private var recordingsHash: Int {
        vm.recordingsHash(from: recordings)
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .sheet(isPresented: $vm.isCreatingFolder, content: createFolderSheet)
            .sheet(item: $vm.renamingRecording, content: renameRecordingSheet)
            .sheet(item: .constant(vm.renamingFolderWrapper), content: renameFolderSheet)
            .alert(item: playbackErrorBinding, content: playbackErrorAlert)
            .alert("Recording Failed", isPresented: vm.recordingErrorBinding, actions: { Button("OK") { vm.recordingManager.lastError = nil } }, message: { Text(vm.recordingManager.lastError ?? "Unable to start recording.") })
            .confirmationDialog("Delete Recording?", isPresented: $vm.isShowingDeleteConfirmation, presenting: vm.recordingPendingDeletion, actions: deleteRecordingActions, message: deleteRecordingMessage)
            .confirmationDialog("Delete Folder?", isPresented: $vm.isShowingFolderDeleteConfirmation, presenting: vm.folderPendingDeletion, actions: deleteFolderActions, message: deleteFolderMessage)
            .task(id: recordingsHash) { await vm.refreshDurationsIfNeeded(recordings: recordings, context: modelContext) }
            .task { await vm.recoverIncompleteRecordings(recordings: recordings, context: modelContext) }
            .task { vm.autoDeleteExpiredRecordings(recordings: recordings, context: modelContext) }
            .onChange(of: vm.selectedSidebarItem) { _, _ in recalcSelection() }
            .onChange(of: recordingsHash) { _, _ in recalcSelection(keepExisting: true) }
            .onChange(of: vm.searchText) { _, _ in recalcSelection(keepExisting: true) }
            .onChange(of: hideFromScreenSharing) { _, newValue in vm.applyScreenSharingPreference(newValue) }
            .onAppear { handleAppear() }
            .onChange(of: appState.toggleSidebarTrigger) { _, _ in
                withAnimation { vm.isSidebarVisible.toggle() }
            }
            .onChange(of: appState.startRecordingTrigger) { _, _ in handleStartRecording() }
            .onChange(of: appState.stopRecordingTrigger) { _, _ in handleStopRecording() }
            .onChange(of: appState.clearDeletedRecordingsTrigger) { _, _ in
                vm.clearAllDeletedRecordings(recordings: recordings, context: modelContext, playbackManager: playbackManager)
            }
            .toolbar(content: toolbarContent)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottomLeading) {
            contentLayout
            recordButton
        }
    }

    private var contentLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            if vm.isSidebarVisible {
                sidebarSection
            }
            recordingsSection
            detailPanel
        }
        .frame(minWidth: 960, minHeight: 600)
    }

    private var sidebarSection: some View {
        Group {
            SidebarView(
                selectedItem: $vm.selectedSidebarItem,
                folders: vm.userFolders(from: folders),
                width: sidebarWidth,
                onDeleteFolder: vm.confirmFolderDeletion,
                onRenameFolder: vm.startRenamingFolder
            )
            Divider()
        }
    }

    private var recordingsSection: some View {
        Group {
            RecordingsListView(
                title: vm.sidebarTitle,
                recordings: filteredRecordings,
                selectedRecordingID: $vm.selectedRecordingID,
                searchText: $vm.searchText,
                activeRecordingID: playbackManager.activeRecordingID,
                onSelect: { id in vm.updatePlayback(for: id, recordings: recordings, playbackManager: playbackManager) },
                onToggleFavorite: { rec in vm.toggleFavorite(rec, context: modelContext, recordings: recordings, playbackManager: playbackManager) },
                onMoveToFolder: { rec in vm.promptForFolder(rec, context: modelContext, folders: folders, recordings: recordings, playbackManager: playbackManager) },
                onReveal: vm.reveal,
                onDelete: vm.confirmDelete
            )
            Divider()
        }
    }

    private var recordButton: some View {
        RecordButtonView(isRecording: vm.recordingManager.isRecording) {
            Task {
                if vm.recordingManager.isRecording {
                    await vm.recordingManager.stopRecordingFlow(modelContext: modelContext)
                    recalcSelection()
                } else {
                    await vm.recordingManager.startRecordingFlow(
                        modelContext: modelContext,
                        hideFromScreenSharing: hideFromScreenSharing
                    ) { recalcSelection() }
                    vm.selectedSidebarItem = .library(.all)
                    if let pending = vm.recordingManager.pendingRecording {
                        vm.selectedRecordingID = pending.id
                    }
                    recalcSelection(selectNewest: true)
                }
            }
        }
        .padding(.leading, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if let recording = selectedRecording {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        RecordingDetailHeader(recording: recording)

                        if recording.deletedAt != nil {
                            DeletedRecordingMessage(recording: recording)
                        } else {
                            PlaybackControlsView(recording: recording)
                                .environmentObject(playbackManager)
                        }
                    }
                    .padding(20)
                }
            } else {
                EmptyDetailState()
            }
        }
        .frame(minWidth: 350)
    }

    // MARK: - Helpers

    private func recalcSelection(keepExisting: Bool = false, selectNewest: Bool = false) {
        vm.recalcSelection(recordings: recordings, playbackManager: playbackManager, keepExisting: keepExisting, selectNewest: selectNewest)
    }

    private func handleAppear() {
        recalcSelection()
        vm.applyScreenSharingPreference(hideFromScreenSharing)
    }

    private func handleStartRecording() {
        guard !vm.recordingManager.isRecording else { return }
        Task {
            await vm.recordingManager.startRecordingFlow(
                modelContext: modelContext,
                hideFromScreenSharing: hideFromScreenSharing
            ) { recalcSelection() }
            vm.selectedSidebarItem = .library(.all)
            recalcSelection(selectNewest: true)
        }
    }

    private func handleStopRecording() {
        guard vm.recordingManager.isRecording else { return }
        Task {
            await vm.recordingManager.stopRecordingFlow(modelContext: modelContext)
            recalcSelection()
        }
    }

    // MARK: - Sharing

    private func shareRecording(_ recording: RecordingEntity) {
        guard let shareURL = vm.shareFileURL(for: recording) else { return }

        GrowthMetricsTracker.track(.shareClicked)
        sharePresenter.present(items: [shareURL, vm.shareText(for: recording)]) { event in
            switch event {
            case .clicked: GrowthMetricsTracker.track(.shareClicked)
            case .completed: GrowthMetricsTracker.track(.shareCompleted)
            case .failed(let msg): showShareErrorAlert(msg)
            }
        }
    }

    private func showShareErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Share Failed"
        alert.informativeText = message.isEmpty ? "Unable to share this recording." : message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Alert / Sheet Builders

    private var playbackErrorBinding: Binding<PlaybackManager.PlaybackError?> {
        Binding(get: { playbackManager.error }, set: { playbackManager.error = $0 })
    }

    @ViewBuilder
    private func createFolderSheet() -> some View {
        CreateFolderSheet(folderName: $vm.newFolderName) { name in
            vm.createFolder(name: name, folders: folders, context: modelContext)
            vm.isCreatingFolder = false
        } onCancel: {
            vm.isCreatingFolder = false
            vm.newFolderName = ""
        }
    }

    @ViewBuilder
    private func renameRecordingSheet(_ recording: RecordingEntity) -> some View {
        RenameRecordingSheet(recordingTitle: recording.title, newTitle: $vm.renameText) { newTitle in
            vm.renameRecording(recording, to: newTitle, context: modelContext, recordings: recordings, playbackManager: playbackManager)
            vm.renamingRecording = nil
        } onCancel: {
            vm.renamingRecording = nil
            vm.renameText = ""
        }
    }

    @ViewBuilder
    private func renameFolderSheet(_ wrapper: FolderWrapper) -> some View {
        RenameFolderSheet(folderName: wrapper.name, newName: $vm.renameFolderText) { newName in
            vm.renameFolder(from: wrapper.name, to: newName, folders: folders, context: modelContext)
            vm.renamingFolder = nil
        } onCancel: {
            vm.renamingFolder = nil
            vm.renameFolderText = ""
        }
    }

    private func playbackErrorAlert(_ error: PlaybackManager.PlaybackError) -> Alert {
        Alert(title: Text("Playback Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
    }

    @ViewBuilder
    private func deleteRecordingActions(_ recording: RecordingEntity) -> some View {
        Button("Delete", role: .destructive) {
            vm.performDeletion(recording, context: modelContext, playbackManager: playbackManager, recordings: recordings)
        }
        Button("Cancel", role: .cancel) { vm.recordingPendingDeletion = nil }
    }

    private func deleteRecordingMessage(_ recording: RecordingEntity) -> Text {
        Text("Are you sure you want to delete \(recording.title)?")
    }

    @ViewBuilder
    private func deleteFolderActions(_ folderName: String) -> some View {
        Button("Delete", role: .destructive) {
            vm.performFolderDeletion(folderName, folders: folders, context: modelContext, recordings: recordings, playbackManager: playbackManager)
        }
        Button("Cancel", role: .cancel) { vm.folderPendingDeletion = nil }
    }

    private func deleteFolderMessage(_ folderName: String) -> Text {
        Text("Are you sure you want to delete the folder '\(folderName)'? Recordings in this folder will not be deleted.")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                withAnimation { vm.isSidebarVisible.toggle() }
            } label: {
                Label("Toggle Sidebar", systemImage: "sidebar.left")
            }
            .help("Toggle Sidebar")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                vm.isCreatingFolder = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .help("Create New Folder")

            Button {
                Task {
                    if vm.recordingManager.isRecording {
                        await vm.recordingManager.stopRecordingFlow(modelContext: modelContext)
                        recalcSelection()
                    } else {
                        await vm.recordingManager.startRecordingFlow(
                            modelContext: modelContext,
                            hideFromScreenSharing: hideFromScreenSharing
                        ) { recalcSelection() }
                        vm.selectedSidebarItem = .library(.all)
                        recalcSelection(selectNewest: true)
                    }
                }
            } label: {
                Label(vm.recordingManager.isRecording ? "Stop Recording" : "New Recording",
                      systemImage: vm.recordingManager.isRecording ? "stop.circle.fill" : "record.circle")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button {
                playbackManager.togglePlayPause()
            } label: {
                Label(playbackManager.isPlaying ? "Pause" : "Play",
                      systemImage: playbackManager.isPlaying ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut(" ", modifiers: [])
            .disabled(!playbackManager.hasSelection)
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            if let recording = selectedRecording {
                if recording.deletedAt == nil, vm.shareFileURL(for: recording) != nil {
                    Button { shareRecording(recording) } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .help("Share Recording")
                }

                Button { vm.startRenaming(recording) } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button {
                    vm.toggleFavorite(recording, context: modelContext, recordings: recordings, playbackManager: playbackManager)
                } label: {
                    Label(recording.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: recording.isFavorite ? "star.fill" : "star")
                }
                .keyboardShortcut("f", modifiers: .command)

                Button { vm.reveal(recording) } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button(role: .destructive) { vm.confirmDelete(recording) } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
}

// MARK: - Helper Types

private enum ShareEvent {
    case clicked
    case completed
    case failed(String)
}

@MainActor
private final class RecordingSharePresenter: NSObject, @preconcurrency NSSharingServicePickerDelegate, @preconcurrency NSSharingServiceDelegate {
    private var onEvent: ((ShareEvent) -> Void)?

    func present(items: [Any], onEvent: @escaping (ShareEvent) -> Void) {
        self.onEvent = onEvent

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let contentView = window.contentView else {
            onEvent(.failed("No active window available for sharing."))
            return
        }

        let picker = NSSharingServicePicker(items: items)
        picker.delegate = self
        let anchor = NSRect(x: contentView.bounds.midX, y: contentView.bounds.maxY - 6, width: 1, height: 1)
        picker.show(relativeTo: anchor, of: contentView, preferredEdge: .minY)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        service?.delegate = self
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        onEvent?(.completed)
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        onEvent?(.failed(error.localizedDescription))
    }
}

struct FolderWrapper: Identifiable {
    let name: String
    var id: String { name }
}

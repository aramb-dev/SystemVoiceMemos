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

/// Main application view coordinating recordings, folders, and playback
/// 
/// This view manages:
/// - Sidebar navigation with library categories and custom folders
/// - Recordings list with search and filtering
/// - Detail panel with playback controls and recording information
/// - Recording management (create, rename, delete, organize)
/// - Folder management (create, rename, delete)
struct ContentView: View {
    // MARK: - Environment & Data
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playbackManager: PlaybackManager
    
    /// All recordings sorted by creation date (newest first)
    @Query(sort: \RecordingEntity.createdAt, order: .reverse)
    private var recordings: [RecordingEntity]
    
    /// All folders sorted by custom sort order
    @Query(sort: \FolderEntity.sortOrder)
    private var folders: [FolderEntity]

    // MARK: - State Management
    
    /// Manages recording lifecycle and floating panel
    @State private var recordingManager = RecordingManager()
    
    /// User preference for hiding app from screen sharing
    @AppStorage(AppConstants.UserDefaultsKeys.hideFromScreenSharing) private var hideFromScreenSharing = true
    
    /// Currently selected recording in the list
    @State private var selectedRecordingID: RecordingEntity.ID?
    
    /// Recording awaiting deletion confirmation
    @State private var recordingPendingDeletion: RecordingEntity?
    
    /// Shows delete recording confirmation dialog
    @State private var isShowingDeleteConfirmation = false
    
    /// Search text for filtering recordings
    @State private var searchText = ""
    
    /// Currently selected sidebar item (library category or folder)
    @State private var selectedSidebarItem: SidebarItem? = .library(.all)
    
    /// Controls sidebar visibility
    @State private var isSidebarVisible = true
    
    /// Shows create folder sheet
    @State private var isCreatingFolder = false
    
    /// Name for new folder being created
    @State private var newFolderName = ""
    
    /// Recording being renamed
    @State private var renamingRecording: RecordingEntity?
    
    /// New name for recording being renamed
    @State private var renameText = ""
    
    /// Folder name being renamed
    @State private var renamingFolder: String?
    
    /// New name for folder being renamed
    @State private var renameFolderText = ""
    
    /// Folder awaiting deletion confirmation
    @State private var folderPendingDeletion: String?
    
    /// Shows delete folder confirmation dialog
    @State private var isShowingFolderDeleteConfirmation = false

    /// AppKit presenter for native share picker
    @State private var sharePresenter = RecordingSharePresenter()

    // MARK: - Constants
    
    /// Fixed width for the sidebar
    private let sidebarWidth: CGFloat = 220
    
    // MARK: - Computed Properties
    
    /// Wraps the renaming folder name for sheet presentation
    private var renamingFolderWrapper: FolderWrapper? {
        renamingFolder.map { FolderWrapper(name: $0) }
    }

    var body: some View {
        mainContent
            .sheet(isPresented: $isCreatingFolder, content: createFolderSheet)
            .sheet(item: $renamingRecording, content: renameRecordingSheet)
            .sheet(item: .constant(renamingFolderWrapper), content: renameFolderSheet)
            .alert(item: playbackErrorBinding, content: playbackErrorAlert)
            .alert("Recording Failed", isPresented: recordingErrorBinding, actions: { Button("OK") { recordingManager.lastError = nil } }, message: { Text(recordingManager.lastError ?? "Unable to start recording.") })
            .confirmationDialog("Delete Recording?", isPresented: $isShowingDeleteConfirmation, presenting: recordingPendingDeletion, actions: deleteRecordingActions, message: deleteRecordingMessage)
            .confirmationDialog("Delete Folder?", isPresented: $isShowingFolderDeleteConfirmation, presenting: folderPendingDeletion, actions: deleteFolderActions, message: deleteFolderMessage)
            .task(id: recordingsHash) { await refreshDurationsIfNeeded() }
            .task { await recoverIncompleteRecordings() }
            .task { autoDeleteExpiredRecordings() }
            .onChange(of: selectedSidebarItem) { _, _ in recalcSelection() }
            .onChange(of: recordingsHash) { _, _ in recalcSelection(keepExisting: true) }
            .onChange(of: searchText) { _, _ in recalcSelection(keepExisting: true) }
            .onChange(of: hideFromScreenSharing) { _, newValue in applyScreenSharingPreference(newValue) }
            .onAppear(perform: handleAppear)
            .onReceive(NotificationCenter.default.publisher(for: .showOnboarding), perform: handleShowOnboarding)
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar), perform: handleToggleSidebar)
            .onReceive(NotificationCenter.default.publisher(for: .startRecording), perform: handleStartRecording)
            .onReceive(NotificationCenter.default.publisher(for: .stopRecording), perform: handleStopRecording)
            .onReceive(NotificationCenter.default.publisher(for: .clearDeletedRecordings), perform: handleClearDeleted)
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
            if isSidebarVisible {
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
                selectedItem: $selectedSidebarItem,
                folders: userFolders,
                width: sidebarWidth,
                onDeleteFolder: confirmFolderDeletion,
                onRenameFolder: startRenamingFolder
            )
            Divider()
        }
    }
    
    private var recordingsSection: some View {
        Group {
            RecordingsListView(
                title: sidebarTitle,
                recordings: filteredRecordings,
                selectedRecordingID: $selectedRecordingID,
                searchText: $searchText,
                activeRecordingID: playbackManager.activeRecordingID,
                onSelect: handleSelectionChange,
                onToggleFavorite: toggleFavorite,
                onMoveToFolder: promptForFolder,
                onReveal: reveal,
                onDelete: confirmDelete
            )
            Divider()
        }
    }
    
    private var recordButton: some View {
        RecordButtonView(isRecording: recordingManager.isRecording) {
            Task {
                if recordingManager.isRecording {
                    await recordingManager.stopRecordingFlow(modelContext: modelContext)
                    recalcSelection()
                } else {
                    await recordingManager.startRecordingFlow(
                        modelContext: modelContext,
                        hideFromScreenSharing: hideFromScreenSharing
                    ) {
                        recalcSelection()
                    }
                    selectedSidebarItem = .library(.all)
                    if let pending = recordingManager.pendingRecording {
                        selectedRecordingID = pending.id
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
                        detailHeader(for: recording)
                        
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
    
    /// Title for the recordings list based on selected sidebar item
    private var sidebarTitle: String {
        guard let item = selectedSidebarItem else { return "Library" }
        switch item {
        case .library(let category):
            return category.title
        case .folder(let name):
            return name
        }
    }

    // MARK: - Selection Management

    /// The currently selected recording entity
    private var selectedRecording: RecordingEntity? {
        guard let id = selectedRecordingID else { return nil }
        return recordings.first(where: { $0.id == id })
    }

    /// Recordings filtered by selected sidebar item and search text
    private var filteredRecordings: [RecordingEntity] {
        let selection = selectedSidebarItem ?? .library(.all)

        let base: [RecordingEntity]
        switch selection {
        case .library(.all):
            base = recordings.filter { $0.deletedAt == nil }
        case .library(.favorites):
            base = recordings.filter { $0.deletedAt == nil && $0.isFavorite }
        case .library(.recentlyDeleted):
            base = recordings.filter { $0.deletedAt != nil }
        case .folder(let name):
            base = recordings.filter { $0.deletedAt == nil && $0.folder == name }
        }

        guard !searchText.isEmpty else { return base }
        let lowered = searchText.lowercased()
        return base.filter { rec in
            rec.title.lowercased().contains(lowered)
        }
    }

    /// Combined list of persisted folders and folders referenced by recordings
    private var userFolders: [String] {
        let persistedFolders = folders.map { $0.name }
        let recordingFolders = recordings.compactMap { $0.folder?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let allFolders = Set(persistedFolders + recordingFolders.filter { !$0.isEmpty })
        return Array(allFolders).sorted()
    }

    /// Hash of all recording IDs for change detection
    private var recordingsHash: Int {
        recordings.reduce(into: 0) { partial, rec in
            partial = partial &+ rec.id.hashValue
        }
    }

    /// Recalculates the selected recording based on current filters
    /// - Parameters:
    ///   - keepExisting: If true, keeps current selection if it's still visible
    ///   - selectNewest: If true, selects the newest recording
    private func recalcSelection(keepExisting: Bool = false, selectNewest: Bool = false) {
        if selectNewest, let newest = filteredRecordings.first {
            selectedRecordingID = newest.id
            handleSelectionChange(newValue: newest.id)
            return
        }

        if keepExisting,
           let currentID = selectedRecordingID,
           filteredRecordings.contains(where: { $0.id == currentID }) {
            handleSelectionChange(newValue: currentID)
            return
        }

        if let first = filteredRecordings.first {
            selectedRecordingID = first.id
            handleSelectionChange(newValue: first.id)
        } else {
            selectedRecordingID = nil
            playbackManager.select(recording: nil)
        }
    }

    /// Handles recording selection changes and updates playback manager
    /// - Parameter newValue: The newly selected recording ID
    private func handleSelectionChange(newValue: RecordingEntity.ID?) {
        guard let newValue,
              let rec = recordings.first(where: { $0.id == newValue }) else {
            playbackManager.select(recording: nil)
            return
        }
        if rec.deletedAt != nil {
            playbackManager.select(recording: nil)
        } else {
            playbackManager.select(recording: rec, autoPlay: false)
        }
    }

    // MARK: - Duration Management
    
    /// Refreshes durations for recordings with missing or zero duration
    private func refreshDurationsIfNeeded() async {
        var didUpdate = false
        for recording in recordings where recording.duration <= 0 {
            guard let url = try? url(for: recording) else { continue }
            let asset = AVURLAsset(url: url)
            do {
                let cmDuration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(cmDuration)
                if seconds.isFinite && seconds > 0.01 {
                    recording.duration = seconds
                    didUpdate = true
                }
            } catch {
                print("duration load error:", error)
            }
        }
        if didUpdate {
            try? modelContext.save()
        }
    }

    // MARK: - Recording Actions
    
    /// Shows confirmation dialog before deleting a recording
    /// - Parameter rec: The recording to delete
    private func confirmDelete(_ rec: RecordingEntity) {
        recordingPendingDeletion = rec
        isShowingDeleteConfirmation = true
    }

    /// Performs the actual deletion of a recording
    /// - Parameter rec: The recording to delete
    private func performDeletion(_ rec: RecordingEntity) {
        defer {
            recordingPendingDeletion = nil
            isShowingDeleteConfirmation = false
        }

        if rec.deletedAt == nil, let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                print("trashItem error:", error)
            }
        }

        if rec.deletedAt != nil {
            modelContext.delete(rec)
            try? modelContext.save()
        } else {
            rec.deletedAt = .now
            try? modelContext.save()
        }

        if selectedRecordingID == rec.id {
            selectedRecordingID = nil
        }
        playbackManager.handleDeletion(of: rec.id)
        recalcSelection()
    }

    /// Toggles the favorite status of a recording
    /// - Parameter rec: The recording to toggle
    private func toggleFavorite(_ rec: RecordingEntity) {
        rec.isFavorite.toggle()
        try? modelContext.save()
        recalcSelection(keepExisting: true)
    }

    /// Shows a dialog to assign a folder to a recording
    /// - Parameter rec: The recording to organize
    private func promptForFolder(_ rec: RecordingEntity) {
        let alert = NSAlert()
        alert.messageText = "Assign Folder"
        alert.informativeText = "Enter a folder name for this recording."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(string: rec.folder ?? "")
        input.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            rec.folder = trimmed.isEmpty ? nil : trimmed
            try? modelContext.save()
            recalcSelection(keepExisting: true)
        }
    }

    /// Reveals the recording file in Finder
    /// - Parameter rec: The recording to reveal
    private func reveal(_ rec: RecordingEntity) {
        if let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Handles share events and tracks growth metrics
    /// - Parameter event: Share event emitted by the share button
    private func handleShareEvent(_ event: ShareEvent) {
        switch event {
        case .clicked:
            GrowthMetricsTracker.track(.shareClicked)
        case .completed:
            GrowthMetricsTracker.track(.shareCompleted)
        case .failed(let errorMessage):
            showShareErrorAlert(errorMessage)
        }
    }

    /// Gets the file URL for a recording
    /// - Parameter recording: The recording entity
    /// - Returns: The file URL
    /// - Throws: Error if recordings directory cannot be accessed
    private func url(for recording: RecordingEntity) throws -> URL {
        let dir = try AppDirectories.recordingsDir()
        return dir.appendingPathComponent(recording.fileName)
    }

    /// Applies screen sharing exclusion preference to all windows
    /// - Parameter exclude: Whether to exclude from screen sharing
    private func applyScreenSharingPreference(_ exclude: Bool) {
        NSApp.windows.forEach { window in
            window.sharingType = exclude ? .none : .readOnly
        }
        recordingManager.setScreenCaptureExclusion(exclude)
    }

    /// Builds the detail header for the selected recording
    /// - Parameter recording: The current recording
    /// - Returns: Header view with recording metadata
    @ViewBuilder
    private func detailHeader(for recording: RecordingEntity) -> some View {
        RecordingDetailHeader(recording: recording)
    }

    /// Builds share text with lightweight app attribution
    /// - Parameter recording: The recording being shared
    /// - Returns: User-visible share copy
    private func shareText(for recording: RecordingEntity) -> String {
        "Shared from System Voice Memos: \(recording.title)\nGet the app: https://github.com/aramb-dev/SystemVoiceMemos"
    }

    /// Resolves a recording file URL if the file exists
    /// - Parameter recording: The recording entity
    /// - Returns: Existing file URL or nil
    private func shareFileURL(for recording: RecordingEntity) -> URL? {
        guard let fileURL = try? url(for: recording) else { return nil }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    /// Opens native share picker from the current active window
    /// - Parameter recording: Recording to share
    private func shareRecording(_ recording: RecordingEntity) {
        guard let shareURL = shareFileURL(for: recording) else { return }

        handleShareEvent(.clicked)
        sharePresenter.present(items: [shareURL, shareText(for: recording)]) { event in
            handleShareEvent(event)
        }
    }

    /// Presents a blocking alert for share failures
    /// - Parameter message: Error details from the share service
    private func showShareErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Share Failed"
        alert.informativeText = message.isEmpty ? "Unable to share this recording." : message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Rename Operations
    
    /// Initiates renaming flow for a recording
    /// - Parameter recording: The recording to rename
    private func startRenaming(_ recording: RecordingEntity) {
        renameText = recording.title
        renamingRecording = recording
    }
    
    /// Renames a recording with validation
    /// - Parameters:
    ///   - recording: The recording to rename
    ///   - newTitle: The new title
    private func renameRecording(_ recording: RecordingEntity, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recording.title = trimmed
        try? modelContext.save()
        recalcSelection(keepExisting: true)
    }
    
    /// Creates a new folder or selects existing one
    /// - Parameter name: The folder name
    private func createFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Check if folder already exists
        guard !folders.contains(where: { $0.name == trimmed }) else {
            selectedSidebarItem = .folder(trimmed)
            return
        }
        
        // Create and persist new folder
        let newFolder = FolderEntity(name: trimmed, sortOrder: folders.count)
        modelContext.insert(newFolder)
        try? modelContext.save()
        
        selectedSidebarItem = .folder(trimmed)
        newFolderName = ""
    }
    
    /// Permanently deletes all recordings in the trash
    private func clearAllDeletedRecordings() {
        let deletedRecordings = recordings.filter { $0.deletedAt != nil }
        
        for recording in deletedRecordings {
            if let dir = try? AppDirectories.recordingsDir() {
                let url = dir.appendingPathComponent(recording.fileName)
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(recording)
        }
        
        try? modelContext.save()
        recalcSelection()
    }
    
    // MARK: - Crash Recovery
    
    /// Recovers or cleans up incomplete recordings from previous sessions
    /// 
    /// This method:
    /// - Finds recordings with zero duration (incomplete/crashed)
    /// - Attempts to read actual duration from the file
    /// - Deletes recordings with missing or invalid files
    private func recoverIncompleteRecordings() async {
        // Find recordings with duration = 0 (incomplete/crashed)
        let incompleteRecordings = recordings.filter { $0.duration == 0 && $0.deletedAt == nil }
        
        for recording in incompleteRecordings {
            guard let url = try? url(for: recording) else {
                // File doesn't exist, delete the entity
                modelContext.delete(recording)
                continue
            }
            
            // Check if file exists and has content
            guard FileManager.default.fileExists(atPath: url.path) else {
                // File doesn't exist, delete the entity
                modelContext.delete(recording)
                continue
            }
            
            // Try to get actual duration from the file
            let asset = AVURLAsset(url: url)
            do {
                let cmDuration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(cmDuration)
                
                if seconds > 0 {
                    // File is valid, update the duration
                    recording.duration = seconds
                    print("✅ Recovered recording: \(recording.title) (\(seconds)s)")
                } else {
                    // File is empty or invalid, delete it
                    try? FileManager.default.removeItem(at: url)
                    modelContext.delete(recording)
                    print("🗑️ Removed empty recording: \(recording.title)")
                }
            } catch {
                // Couldn't read file, delete it
                try? FileManager.default.removeItem(at: url)
                modelContext.delete(recording)
                print("🗑️ Removed invalid recording: \(recording.title)")
            }
        }
        
        try? modelContext.save()
    }

    // MARK: - Auto Delete

    /// Permanently removes soft-deleted recordings that have exceeded the retention period
    private func autoDeleteExpiredRecordings() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "autoDeleteEnabled") else { return }

        let retentionDays = max(defaults.integer(forKey: "autoDeleteAfterDays"), 1)
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .distantPast

        let expired = recordings.filter { rec in
            guard let deletedAt = rec.deletedAt else { return false }
            return deletedAt < cutoff
        }
        guard !expired.isEmpty else { return }

        for recording in expired {
            if let dir = try? AppDirectories.recordingsDir() {
                let url = dir.appendingPathComponent(recording.fileName)
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(recording)
        }

        try? modelContext.save()
    }

    // MARK: - View Helpers
    
    /// Binding for playback error alerts
    private var playbackErrorBinding: Binding<PlaybackManager.PlaybackError?> {
        Binding(get: { playbackManager.error }, set: { playbackManager.error = $0 })
    }

    /// Binding that presents a recording error alert when lastError is non-nil
    private var recordingErrorBinding: Binding<Bool> {
        Binding(get: { recordingManager.lastError != nil }, set: { if !$0 { recordingManager.lastError = nil } })
    }
    
    /// Sheet for creating a new folder
    @ViewBuilder
    private func createFolderSheet() -> some View {
        CreateFolderSheet(folderName: $newFolderName) { name in
            createFolder(name: name)
            isCreatingFolder = false
        } onCancel: {
            isCreatingFolder = false
            newFolderName = ""
        }
    }
    
    /// Sheet for renaming a recording
    /// - Parameter recording: The recording to rename
    @ViewBuilder
    private func renameRecordingSheet(_ recording: RecordingEntity) -> some View {
        RenameRecordingSheet(recordingTitle: recording.title, newTitle: $renameText) { newTitle in
            renameRecording(recording, to: newTitle)
            renamingRecording = nil
        } onCancel: {
            renamingRecording = nil
            renameText = ""
        }
    }
    
    /// Sheet for renaming a folder
    /// - Parameter wrapper: The folder wrapper containing the name
    @ViewBuilder
    private func renameFolderSheet(_ wrapper: FolderWrapper) -> some View {
        RenameFolderSheet(folderName: wrapper.name, newName: $renameFolderText) { newName in
            renameFolder(from: wrapper.name, to: newName)
            renamingFolder = nil
        } onCancel: {
            renamingFolder = nil
            renameFolderText = ""
        }
    }
    
    /// Creates an alert for playback errors
    /// - Parameter error: The playback error
    /// - Returns: Configured alert
    private func playbackErrorAlert(_ error: PlaybackManager.PlaybackError) -> Alert {
        Alert(title: Text("Playback Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
    }
    
    /// Action buttons for delete recording confirmation
    /// - Parameter recording: The recording to delete
    @ViewBuilder
    private func deleteRecordingActions(_ recording: RecordingEntity) -> some View {
        Button("Delete", role: .destructive) { performDeletion(recording) }
        Button("Cancel", role: .cancel) { recordingPendingDeletion = nil }
    }
    
    /// Message for delete recording confirmation
    /// - Parameter recording: The recording to delete
    /// - Returns: Confirmation message
    private func deleteRecordingMessage(_ recording: RecordingEntity) -> Text {
        Text("Are you sure you want to delete \(recording.title)?")
    }
    
    /// Action buttons for delete folder confirmation
    /// - Parameter folderName: The folder to delete
    @ViewBuilder
    private func deleteFolderActions(_ folderName: String) -> some View {
        Button("Delete", role: .destructive) { performFolderDeletion(folderName) }
        Button("Cancel", role: .cancel) { folderPendingDeletion = nil }
    }
    
    /// Message for delete folder confirmation
    /// - Parameter folderName: The folder to delete
    /// - Returns: Confirmation message
    private func deleteFolderMessage(_ folderName: String) -> Text {
        Text("Are you sure you want to delete the folder '\(folderName)'? Recordings in this folder will not be deleted.")
    }
    
    // MARK: - Lifecycle Handlers
    
    /// Handles view appearance
    private func handleAppear() {
        recalcSelection()
        applyScreenSharingPreference(hideFromScreenSharing)
    }
    
    /// Handles show onboarding notification
    /// - Parameter notification: The notification
    private func handleShowOnboarding(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
    }
    
    /// Handles toggle sidebar notification
    /// - Parameter notification: The notification
    private func handleToggleSidebar(_ notification: Notification) {
        withAnimation {
            isSidebarVisible.toggle()
        }
    }
    
    /// Handles start recording notification
    /// - Parameter notification: The notification
    private func handleStartRecording(_ notification: Notification) {
        guard !recordingManager.isRecording else { return }
        Task {
            await recordingManager.startRecordingFlow(
                modelContext: modelContext,
                hideFromScreenSharing: hideFromScreenSharing
            ) {
                recalcSelection()
            }
            selectedSidebarItem = .library(.all)
            recalcSelection(selectNewest: true)
        }
    }
    
    /// Handles stop recording notification
    /// - Parameter notification: The notification
    private func handleStopRecording(_ notification: Notification) {
        guard recordingManager.isRecording else { return }
        Task {
            await recordingManager.stopRecordingFlow(modelContext: modelContext)
            recalcSelection()
        }
    }
    
    /// Handles clear deleted recordings notification
    /// - Parameter notification: The notification
    private func handleClearDeleted(_ notification: Notification) {
        clearAllDeletedRecordings()
    }
    
    // MARK: - Toolbar
    
    /// Builds the main toolbar content
    /// - Returns: Toolbar items for navigation, primary actions, and secondary actions
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                withAnimation {
                    isSidebarVisible.toggle()
                }
            } label: {
                Label("Toggle Sidebar", systemImage: "sidebar.left")
            }
            .help("Toggle Sidebar")
        }
        
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isCreatingFolder = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .help("Create New Folder")
            
            Button {
                Task {
                    if recordingManager.isRecording {
                        await recordingManager.stopRecordingFlow(modelContext: modelContext)
                        recalcSelection()
                    } else {
                        await recordingManager.startRecordingFlow(
                            modelContext: modelContext,
                            hideFromScreenSharing: hideFromScreenSharing
                        ) {
                            recalcSelection()
                        }
                        selectedSidebarItem = .library(.all)
                        recalcSelection(selectNewest: true)
                    }
                }
            } label: {
                Label(recordingManager.isRecording ? "Stop Recording" : "New Recording",
                      systemImage: recordingManager.isRecording ? "stop.circle.fill" : "record.circle")
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
                if recording.deletedAt == nil, shareFileURL(for: recording) != nil {
                    Button {
                        shareRecording(recording)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .help("Share Recording")
                }

                Button {
                    startRenaming(recording)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Button {
                    toggleFavorite(recording)
                } label: {
                    Label(recording.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: recording.isFavorite ? "star.fill" : "star")
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Button {
                    reveal(recording)
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Button(role: .destructive) {
                    confirmDelete(recording)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
    
    // MARK: - Folder Management
    
    /// Initiates renaming flow for a folder
    /// - Parameter folderName: The folder to rename
    private func startRenamingFolder(_ folderName: String) {
        renameFolderText = folderName
        renamingFolder = folderName
    }
    
    /// Renames a folder and updates all references
    /// - Parameters:
    ///   - oldName: The current folder name
    ///   - newName: The new folder name
    private func renameFolder(from oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        
        // Update folder entity if it exists
        if let folderEntity = folders.first(where: { $0.name == oldName }) {
            folderEntity.name = trimmed
        }
        
        // Update all recordings that reference this folder
        for recording in recordings where recording.folder == oldName {
            recording.folder = trimmed
        }
        
        try? modelContext.save()
        
        // Update selection if the renamed folder was selected
        if selectedSidebarItem == .folder(oldName) {
            selectedSidebarItem = .folder(trimmed)
        }
        
        renameFolderText = ""
    }
    
    /// Shows confirmation dialog before deleting a folder
    /// - Parameter folderName: The folder to delete
    private func confirmFolderDeletion(_ folderName: String) {
        folderPendingDeletion = folderName
        isShowingFolderDeleteConfirmation = true
    }
    
    /// Performs the actual deletion of a folder
    /// 
    /// Note: This removes the folder but preserves recordings,
    /// simply clearing their folder reference.
    /// 
    /// - Parameter folderName: The folder to delete
    private func performFolderDeletion(_ folderName: String) {
        defer {
            folderPendingDeletion = nil
            isShowingFolderDeleteConfirmation = false
        }
        
        // Delete folder entity if it exists
        if let folderEntity = folders.first(where: { $0.name == folderName }) {
            modelContext.delete(folderEntity)
        }
        
        // Remove folder reference from all recordings
        for recording in recordings where recording.folder == folderName {
            recording.folder = nil
        }
        
        try? modelContext.save()
        
        // Update selection if the deleted folder was selected
        if selectedSidebarItem == .folder(folderName) {
            selectedSidebarItem = .library(.all)
        }
        
        recalcSelection()
    }
}

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

// MARK: - Helper Types

/// Wrapper for folder names to make them Identifiable for sheet presentation
struct FolderWrapper: Identifiable {
    let name: String
    var id: String { name }
}

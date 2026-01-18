import SwiftUI
import AppKit
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playbackManager: PlaybackManager
    @Query(sort: \RecordingEntity.createdAt, order: .reverse)
    private var recordings: [RecordingEntity]

    @State private var recordingManager = RecordingManager()
    @AppStorage(AppConstants.UserDefaultsKeys.hideFromScreenSharing) private var hideFromScreenSharing = true
    @State private var selectedRecordingID: RecordingEntity.ID?
    @State private var recordingPendingDeletion: RecordingEntity?
    @State private var isShowingDeleteConfirmation = false
    @State private var searchText = ""
    @State private var selectedSidebarItem: SidebarItem? = .library(.all)

    private let sidebarWidth: CGFloat = 220

    var body: some View {
       ZStack(alignment: .bottomLeading) {
            HStack(alignment: .top, spacing: 0) {
                SidebarView(
                    selectedItem: $selectedSidebarItem,
                    folders: userFolders,
                    width: sidebarWidth
                )
                Divider()
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
                detailPanel
            }
            .frame(minWidth: 960, minHeight: 600)

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
        .task(id: recordingsHash) { await refreshDurationsIfNeeded() }
        .alert(item: Binding(get: { playbackManager.error }, set: { playbackManager.error = $0 })) { error in
            Alert(title: Text("Playback Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog("Delete Recording?", isPresented: $isShowingDeleteConfirmation, presenting: recordingPendingDeletion) { recording in
            Button("Delete", role: .destructive) { performDeletion(recording) }
            Button("Cancel", role: .cancel) { recordingPendingDeletion = nil }
        } message: { recording in
            Text("Are you sure you want to delete \(recording.title)?")
        }
        .onChange(of: selectedSidebarItem) { _, _ in
            recalcSelection()
        }
        .onChange(of: recordingsHash) { _, _ in
            recalcSelection(keepExisting: true)
        }
        .onChange(of: searchText) { _, _ in
            recalcSelection(keepExisting: true)
        }
        .onAppear {
            recalcSelection()
            applyScreenSharingPreference(hideFromScreenSharing)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
            UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
        }
        .onChange(of: hideFromScreenSharing) { _, newValue in
            applyScreenSharingPreference(newValue)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
    
    private var sidebarTitle: String {
        guard let item = selectedSidebarItem else { return "Library" }
        switch item {
        case .library(let category):
            return category.title
        case .folder(let name):
            return name
        }
    }

    // MARK: - Helpers

    private var selectedRecording: RecordingEntity? {
        guard let id = selectedRecordingID else { return nil }
        return recordings.first(where: { $0.id == id })
    }

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

    private var userFolders: [String] {
        let names = recordings.compactMap { $0.folder?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(names.filter { !$0.isEmpty })).sorted()
    }

    private var recordingsHash: Int {
        recordings.reduce(into: 0) { partial, rec in
            partial = partial &+ rec.id.hashValue
        }
    }

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

    private func confirmDelete(_ rec: RecordingEntity) {
        recordingPendingDeletion = rec
        isShowingDeleteConfirmation = true
    }

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

    private func toggleFavorite(_ rec: RecordingEntity) {
        rec.isFavorite.toggle()
        try? modelContext.save()
        recalcSelection(keepExisting: true)
    }

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

    private func reveal(_ rec: RecordingEntity) {
        if let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func url(for recording: RecordingEntity) throws -> URL {
        let dir = try AppDirectories.recordingsDir()
        return dir.appendingPathComponent(recording.fileName)
    }

    private func applyScreenSharingPreference(_ exclude: Bool) {
        NSApp.windows.forEach { window in
            window.sharingType = exclude ? .none : .readOnly
        }
        recordingManager.setScreenCaptureExclusion(exclude)
    }
}

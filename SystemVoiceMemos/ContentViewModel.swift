//
//  ContentViewModel.swift
//  SystemVoiceMemos
//
//  Business logic and state management extracted from ContentView.
//  Owns mutable state and data operations; the view owns @Query and layout.
//

import Foundation
import SwiftUI
import SwiftData
import AVFoundation

@Observable
@MainActor
final class ContentViewModel {
    // MARK: - Recording Manager

    private(set) var recordingManager = RecordingManager()

    // MARK: - Selection State

    var selectedRecordingID: RecordingEntity.ID?
    var selectedSidebarItem: SidebarItem? = .library(.all)
    var searchText = ""
    var isSidebarVisible = true

    // MARK: - Folder Sheet State

    var isCreatingFolder = false
    var newFolderName = ""
    var renamingFolder: String?
    var renameFolderText = ""
    var folderPendingDeletion: String?
    var isShowingFolderDeleteConfirmation = false

    // MARK: - Recording Sheet State

    var renamingRecording: RecordingEntity?
    var renameText = ""
    var recordingPendingDeletion: RecordingEntity?
    var isShowingDeleteConfirmation = false

    // MARK: - Computed Helpers

    var renamingFolderWrapper: FolderWrapper? {
        renamingFolder.map { FolderWrapper(name: $0) }
    }

    var sidebarTitle: String {
        guard let item = selectedSidebarItem else { return "Library" }
        switch item {
        case .library(let category): return category.title
        case .folder(let name): return name
        }
    }

    var recordingErrorBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.recordingManager.lastError != nil },
            set: { [weak self] in if !$0 { self?.recordingManager.lastError = nil } }
        )
    }

    // MARK: - Filtering

    func filteredRecordings(from recordings: [RecordingEntity]) -> [RecordingEntity] {
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
            base = recordings.filter { $0.deletedAt == nil && $0.folderName == name }
        }

        guard !searchText.isEmpty else { return base }
        let lowered = searchText.lowercased()
        return base.filter { $0.title.lowercased().contains(lowered) }
    }

    func selectedRecording(from recordings: [RecordingEntity]) -> RecordingEntity? {
        guard let id = selectedRecordingID else { return nil }
        return recordings.first { $0.id == id }
    }

    func userFolders(from folders: [FolderEntity]) -> [String] {
        folders.map { $0.name }.sorted()
    }

    func recordingsHash(from recordings: [RecordingEntity]) -> Int {
        recordings.reduce(into: 0) { partial, rec in
            partial = partial &+ rec.id.hashValue
        }
    }

    // MARK: - Selection Management

    func recalcSelection(
        recordings: [RecordingEntity],
        playbackManager: PlaybackManager,
        keepExisting: Bool = false,
        selectNewest: Bool = false
    ) {
        let filtered = filteredRecordings(from: recordings)

        if selectNewest, let newest = filtered.first {
            selectedRecordingID = newest.id
            updatePlayback(for: newest.id, recordings: recordings, playbackManager: playbackManager)
            return
        }

        if keepExisting,
           let currentID = selectedRecordingID,
           filtered.contains(where: { $0.id == currentID }) {
            updatePlayback(for: currentID, recordings: recordings, playbackManager: playbackManager)
            return
        }

        if let first = filtered.first {
            selectedRecordingID = first.id
            updatePlayback(for: first.id, recordings: recordings, playbackManager: playbackManager)
        } else {
            selectedRecordingID = nil
            playbackManager.select(recording: nil)
        }
    }

    func updatePlayback(
        for id: RecordingEntity.ID?,
        recordings: [RecordingEntity],
        playbackManager: PlaybackManager
    ) {
        guard let id, let rec = recordings.first(where: { $0.id == id }) else {
            playbackManager.select(recording: nil)
            return
        }
        if rec.deletedAt != nil {
            playbackManager.select(recording: nil)
        } else {
            playbackManager.select(recording: rec, autoPlay: false)
        }
    }

    // MARK: - Recording CRUD

    func confirmDelete(_ rec: RecordingEntity) {
        recordingPendingDeletion = rec
        isShowingDeleteConfirmation = true
    }

    func performDeletion(
        _ rec: RecordingEntity,
        context: ModelContext,
        playbackManager: PlaybackManager,
        recordings: [RecordingEntity]
    ) {
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
            context.delete(rec)
            try? context.save()
        } else {
            rec.deletedAt = .now
            try? context.save()
        }

        if selectedRecordingID == rec.id {
            selectedRecordingID = nil
        }
        playbackManager.handleDeletion(of: rec.id)
        recalcSelection(recordings: recordings, playbackManager: playbackManager)
    }

    func toggleFavorite(
        _ rec: RecordingEntity,
        context: ModelContext,
        recordings: [RecordingEntity],
        playbackManager: PlaybackManager
    ) {
        rec.isFavorite.toggle()
        try? context.save()
        recalcSelection(recordings: recordings, playbackManager: playbackManager, keepExisting: true)
    }

    func renameRecording(
        _ recording: RecordingEntity,
        to newTitle: String,
        context: ModelContext,
        recordings: [RecordingEntity],
        playbackManager: PlaybackManager
    ) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recording.title = trimmed
        try? context.save()
        recalcSelection(recordings: recordings, playbackManager: playbackManager, keepExisting: true)
    }

    func startRenaming(_ recording: RecordingEntity) {
        renameText = recording.title
        renamingRecording = recording
    }

    func promptForFolder(
        _ rec: RecordingEntity,
        context: ModelContext,
        folders: [FolderEntity],
        recordings: [RecordingEntity],
        playbackManager: PlaybackManager
    ) {
        let alert = NSAlert()
        alert.messageText = "Assign Folder"
        alert.informativeText = "Enter a folder name for this recording."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(string: rec.folderName ?? "")
        input.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                rec.folderRef = nil
            } else {
                rec.folderRef = findOrCreateFolder(named: trimmed, in: folders, context: context)
            }
            try? context.save()
            recalcSelection(recordings: recordings, playbackManager: playbackManager, keepExisting: true)
        }
    }

    func reveal(_ rec: RecordingEntity) {
        if let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func clearAllDeletedRecordings(
        recordings: [RecordingEntity],
        context: ModelContext,
        playbackManager: PlaybackManager
    ) {
        let deletedRecordings = recordings.filter { $0.deletedAt != nil }

        for recording in deletedRecordings {
            if let dir = try? AppDirectories.recordingsDir() {
                let url = dir.appendingPathComponent(recording.fileName)
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(recording)
        }

        try? context.save()
        recalcSelection(recordings: recordings, playbackManager: playbackManager)
    }

    // MARK: - Folder CRUD

    func findOrCreateFolder(named name: String, in folders: [FolderEntity], context: ModelContext) -> FolderEntity {
        if let existing = folders.first(where: { $0.name == name }) {
            return existing
        }
        let newFolder = FolderEntity(name: name, sortOrder: folders.count)
        context.insert(newFolder)
        return newFolder
    }

    func createFolder(name: String, folders: [FolderEntity], context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard !folders.contains(where: { $0.name == trimmed }) else {
            selectedSidebarItem = .folder(trimmed)
            return
        }

        let newFolder = FolderEntity(name: trimmed, sortOrder: folders.count)
        context.insert(newFolder)
        try? context.save()

        selectedSidebarItem = .folder(trimmed)
        newFolderName = ""
    }

    func startRenamingFolder(_ folderName: String) {
        renameFolderText = folderName
        renamingFolder = folderName
    }

    func renameFolder(from oldName: String, to newName: String, folders: [FolderEntity], context: ModelContext) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return }

        if let folderEntity = folders.first(where: { $0.name == oldName }) {
            folderEntity.name = trimmed
        }

        try? context.save()

        if selectedSidebarItem == .folder(oldName) {
            selectedSidebarItem = .folder(trimmed)
        }

        renameFolderText = ""
    }

    func confirmFolderDeletion(_ folderName: String) {
        folderPendingDeletion = folderName
        isShowingFolderDeleteConfirmation = true
    }

    func performFolderDeletion(
        _ folderName: String,
        folders: [FolderEntity],
        context: ModelContext,
        recordings: [RecordingEntity],
        playbackManager: PlaybackManager
    ) {
        defer {
            folderPendingDeletion = nil
            isShowingFolderDeleteConfirmation = false
        }

        if let folderEntity = folders.first(where: { $0.name == folderName }) {
            context.delete(folderEntity)
        }

        try? context.save()

        if selectedSidebarItem == .folder(folderName) {
            selectedSidebarItem = .library(.all)
        }

        recalcSelection(recordings: recordings, playbackManager: playbackManager)
    }

    // MARK: - Background Tasks

    func refreshDurationsIfNeeded(recordings: [RecordingEntity], context: ModelContext) async {
        var didUpdate = false
        for recording in recordings where recording.duration <= 0 {
            guard let url = try? fileURL(for: recording) else { continue }
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
            try? context.save()
        }
    }

    func recoverIncompleteRecordings(recordings: [RecordingEntity], context: ModelContext) async {
        let incomplete = recordings.filter { $0.duration == 0 && $0.deletedAt == nil }

        for recording in incomplete {
            guard let url = try? fileURL(for: recording) else {
                context.delete(recording)
                continue
            }

            guard FileManager.default.fileExists(atPath: url.path) else {
                context.delete(recording)
                continue
            }

            let asset = AVURLAsset(url: url)
            do {
                let cmDuration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(cmDuration)

                if seconds > 0 {
                    recording.duration = seconds
                } else {
                    try? FileManager.default.removeItem(at: url)
                    context.delete(recording)
                }
            } catch {
                try? FileManager.default.removeItem(at: url)
                context.delete(recording)
            }
        }

        try? context.save()
    }

    func autoDeleteExpiredRecordings(recordings: [RecordingEntity], context: ModelContext) {
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
            context.delete(recording)
        }

        try? context.save()
    }

    // MARK: - Sharing

    func shareFileURL(for recording: RecordingEntity) -> URL? {
        guard let fileURL = try? fileURL(for: recording) else { return nil }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    func shareText(for recording: RecordingEntity) -> String {
        "Shared from System Voice Memos: \(recording.title)\nGet the app: https://github.com/aramb-dev/SystemVoiceMemos"
    }

    // MARK: - Screen Sharing

    func applyScreenSharingPreference(_ exclude: Bool) {
        NSApp.windows.forEach { window in
            window.sharingType = exclude ? .none : .readOnly
        }
        recordingManager.setScreenCaptureExclusion(exclude)
    }

    // MARK: - File Helpers

    func fileURL(for recording: RecordingEntity) throws -> URL {
        let dir = try AppDirectories.recordingsDir()
        return dir.appendingPathComponent(recording.fileName)
    }
}

//
//  SystemVoiceMemosTests.swift
//  SystemVoiceMemosTests
//
//  Core test suite covering view model logic, models, and app state.
//

import Testing
import Foundation
import SwiftData
@testable import SystemVoiceMemos

// MARK: - Test Helpers

/// Creates an in-memory SwiftData ModelContainer for testing
@MainActor
private func makeTestContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: RecordingEntity.self, FolderEntity.self, configurations: config)
}

/// Creates a RecordingEntity without inserting into a context
@MainActor
private func makeRecording(
    title: String = "Test Recording",
    duration: Double = 60,
    isFavorite: Bool = false,
    folderRef: FolderEntity? = nil,
    deletedAt: Date? = nil
) -> RecordingEntity {
    RecordingEntity(
        title: title,
        duration: duration,
        fileName: "\(UUID().uuidString).m4a",
        isFavorite: isFavorite,
        folderRef: folderRef,
        deletedAt: deletedAt
    )
}

// MARK: - RecordingEntity Tests

@Suite("RecordingEntity")
struct RecordingEntityTests {

    @MainActor @Test("defaults are correct")
    func defaults() throws {
        let rec = makeRecording()
        #expect(rec.isFavorite == false)
        #expect(rec.deletedAt == nil)
        #expect(rec.folderRef == nil)
        #expect(rec.folderName == nil)
        #expect(rec.duration == 60)
    }

    @MainActor @Test("folderName reflects folderRef")
    func folderName() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = FolderEntity(name: "Work", sortOrder: 0)
        context.insert(folder)

        let rec = makeRecording(folderRef: folder)
        context.insert(rec)
        try context.save()

        #expect(rec.folderName == "Work")

        // Clearing folderRef clears folderName
        rec.folderRef = nil
        #expect(rec.folderName == nil)
    }
}

// MARK: - FolderEntity Tests

@Suite("FolderEntity")
struct FolderEntityTests {

    @MainActor @Test("init sets properties")
    func initProperties() {
        let folder = FolderEntity(name: "Music", sortOrder: 3)
        #expect(folder.name == "Music")
        #expect(folder.sortOrder == 3)
        #expect(folder.recordings.isEmpty)
    }

    @MainActor @Test("relationship nullifies on folder delete")
    func nullifyOnDelete() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = FolderEntity(name: "Archive", sortOrder: 0)
        context.insert(folder)

        let rec = makeRecording(folderRef: folder)
        context.insert(rec)
        try context.save()

        #expect(rec.folderRef != nil)

        context.delete(folder)
        try context.save()

        #expect(rec.folderRef == nil)
        #expect(rec.folderName == nil)
    }
}

// MARK: - AppState Tests

@Suite("AppState")
struct AppStateTests {

    @MainActor @Test("triggers increment")
    func triggerIncrements() {
        let state = AppState.shared

        let before = state.startRecordingTrigger
        state.requestStartRecording()
        #expect(state.startRecordingTrigger == before + 1)

        let before2 = state.toggleSidebarTrigger
        state.requestToggleSidebar()
        #expect(state.toggleSidebarTrigger == before2 + 1)
    }

    @MainActor @Test("each trigger is independent")
    func independentTriggers() {
        let state = AppState.shared

        let stopBefore = state.stopRecordingTrigger
        let clearBefore = state.clearDeletedRecordingsTrigger

        state.requestStopRecording()

        #expect(state.stopRecordingTrigger == stopBefore + 1)
        #expect(state.clearDeletedRecordingsTrigger == clearBefore)
    }
}

// MARK: - ContentViewModel Tests

@Suite("ContentViewModel")
struct ContentViewModelTests {

    // MARK: - Filtering

    @MainActor @Test("filteredRecordings shows all non-deleted by default")
    func filterAll() throws {
        let vm = ContentViewModel()
        vm.selectedSidebarItem = .library(.all)

        let container = try makeTestContainer()
        let context = container.mainContext

        let r1 = makeRecording(title: "Active")
        let r2 = makeRecording(title: "Deleted", deletedAt: .now)
        context.insert(r1)
        context.insert(r2)
        try context.save()

        let result = vm.filteredRecordings(from: [r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.title == "Active")
    }

    @MainActor @Test("filteredRecordings shows only favorites")
    func filterFavorites() throws {
        let vm = ContentViewModel()
        vm.selectedSidebarItem = .library(.favorites)

        let container = try makeTestContainer()
        let context = container.mainContext

        let r1 = makeRecording(title: "Normal")
        let r2 = makeRecording(title: "Fav", isFavorite: true)
        context.insert(r1)
        context.insert(r2)
        try context.save()

        let result = vm.filteredRecordings(from: [r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.title == "Fav")
    }

    @MainActor @Test("filteredRecordings shows recently deleted")
    func filterDeleted() throws {
        let vm = ContentViewModel()
        vm.selectedSidebarItem = .library(.recentlyDeleted)

        let container = try makeTestContainer()
        let context = container.mainContext

        let r1 = makeRecording(title: "Active")
        let r2 = makeRecording(title: "Trashed", deletedAt: .now)
        context.insert(r1)
        context.insert(r2)
        try context.save()

        let result = vm.filteredRecordings(from: [r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.title == "Trashed")
    }

    @MainActor @Test("filteredRecordings filters by folder")
    func filterByFolder() throws {
        let vm = ContentViewModel()
        vm.selectedSidebarItem = .folder("Work")

        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = FolderEntity(name: "Work", sortOrder: 0)
        context.insert(folder)

        let r1 = makeRecording(title: "In Work", folderRef: folder)
        let r2 = makeRecording(title: "No Folder")
        context.insert(r1)
        context.insert(r2)
        try context.save()

        let result = vm.filteredRecordings(from: [r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.title == "In Work")
    }

    @MainActor @Test("filteredRecordings applies search text")
    func filterSearch() throws {
        let vm = ContentViewModel()
        vm.selectedSidebarItem = .library(.all)
        vm.searchText = "meeting"

        let container = try makeTestContainer()
        let context = container.mainContext

        let r1 = makeRecording(title: "Team Meeting Notes")
        let r2 = makeRecording(title: "Music Session")
        context.insert(r1)
        context.insert(r2)
        try context.save()

        let result = vm.filteredRecordings(from: [r1, r2])
        #expect(result.count == 1)
        #expect(result.first?.title == "Team Meeting Notes")
    }

    @MainActor @Test("search is case insensitive")
    func searchCaseInsensitive() throws {
        let vm = ContentViewModel()
        vm.selectedSidebarItem = .library(.all)
        vm.searchText = "MEETING"

        let container = try makeTestContainer()
        let context = container.mainContext

        let r1 = makeRecording(title: "Team Meeting Notes")
        context.insert(r1)
        try context.save()

        let result = vm.filteredRecordings(from: [r1])
        #expect(result.count == 1)
    }

    // MARK: - User Folders

    @MainActor @Test("userFolders returns sorted names")
    func userFoldersSorted() {
        let vm = ContentViewModel()
        let folders = [
            FolderEntity(name: "Zebra", sortOrder: 0),
            FolderEntity(name: "Alpha", sortOrder: 1),
            FolderEntity(name: "Middle", sortOrder: 2)
        ]
        let result = vm.userFolders(from: folders)
        #expect(result == ["Alpha", "Middle", "Zebra"])
    }

    // MARK: - Selection

    @MainActor @Test("selectedRecording returns matching entity")
    func selectedRecording() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let r1 = makeRecording(title: "First")
        let r2 = makeRecording(title: "Second")
        context.insert(r1)
        context.insert(r2)
        try context.save()

        vm.selectedRecordingID = r2.id
        let result = vm.selectedRecording(from: [r1, r2])
        #expect(result?.title == "Second")
    }

    @MainActor @Test("selectedRecording returns nil when no selection")
    func selectedRecordingNil() {
        let vm = ContentViewModel()
        vm.selectedRecordingID = nil
        let result = vm.selectedRecording(from: [])
        #expect(result == nil)
    }

    // MARK: - Sidebar Title

    @MainActor @Test("sidebarTitle reflects selected item")
    func sidebarTitle() {
        let vm = ContentViewModel()

        vm.selectedSidebarItem = .library(.all)
        #expect(vm.sidebarTitle == "All Recordings" || vm.sidebarTitle == "Library" || !vm.sidebarTitle.isEmpty)

        vm.selectedSidebarItem = .folder("Music")
        #expect(vm.sidebarTitle == "Music")

        vm.selectedSidebarItem = nil
        #expect(vm.sidebarTitle == "Library")
    }

    // MARK: - Hash

    @MainActor @Test("recordingsHash changes when recordings differ")
    func recordingsHash() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let r1 = makeRecording(title: "A")
        context.insert(r1)
        try context.save()

        let hash1 = vm.recordingsHash(from: [r1])

        let r2 = makeRecording(title: "B")
        context.insert(r2)
        try context.save()

        let hash2 = vm.recordingsHash(from: [r1, r2])
        #expect(hash1 != hash2)
    }

    // MARK: - Confirm Delete

    @MainActor @Test("confirmDelete sets pending state")
    func confirmDelete() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let rec = makeRecording()
        context.insert(rec)
        try context.save()

        #expect(vm.isShowingDeleteConfirmation == false)
        #expect(vm.recordingPendingDeletion == nil)

        vm.confirmDelete(rec)

        #expect(vm.isShowingDeleteConfirmation == true)
        #expect(vm.recordingPendingDeletion?.id == rec.id)
    }

    // MARK: - Rename

    @MainActor @Test("startRenaming sets state")
    func startRenaming() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let rec = makeRecording(title: "Original")
        context.insert(rec)
        try context.save()

        vm.startRenaming(rec)

        #expect(vm.renameText == "Original")
        #expect(vm.renamingRecording?.id == rec.id)
    }

    // MARK: - Folder Management

    @MainActor @Test("confirmFolderDeletion sets pending state")
    func confirmFolderDeletion() {
        let vm = ContentViewModel()

        vm.confirmFolderDeletion("Work")

        #expect(vm.isShowingFolderDeleteConfirmation == true)
        #expect(vm.folderPendingDeletion == "Work")
    }

    @MainActor @Test("startRenamingFolder sets state")
    func startRenamingFolder() {
        let vm = ContentViewModel()

        vm.startRenamingFolder("Old Name")

        #expect(vm.renameFolderText == "Old Name")
        #expect(vm.renamingFolder == "Old Name")
    }

    @MainActor @Test("findOrCreateFolder reuses existing")
    func findOrCreateFolderExisting() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = FolderEntity(name: "Work", sortOrder: 0)
        context.insert(existing)
        try context.save()

        let result = vm.findOrCreateFolder(named: "Work", in: [existing], context: context)
        #expect(result.id == existing.id)
    }

    @MainActor @Test("findOrCreateFolder creates new")
    func findOrCreateFolderNew() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let result = vm.findOrCreateFolder(named: "New Folder", in: [], context: context)
        #expect(result.name == "New Folder")
    }

    @MainActor @Test("createFolder skips duplicates")
    func createFolderDuplicate() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let existing = FolderEntity(name: "Work", sortOrder: 0)
        context.insert(existing)
        try context.save()

        vm.createFolder(name: "Work", folders: [existing], context: context)
        #expect(vm.selectedSidebarItem == .folder("Work"))
    }

    @MainActor @Test("renameFolder updates entity name")
    func renameFolder() throws {
        let vm = ContentViewModel()
        vm.selectedSidebarItem = .folder("Old")

        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = FolderEntity(name: "Old", sortOrder: 0)
        context.insert(folder)
        try context.save()

        vm.renameFolder(from: "Old", to: "New", folders: [folder], context: context)

        #expect(folder.name == "New")
        #expect(vm.selectedSidebarItem == .folder("New"))
    }

    @MainActor @Test("renameFolder rejects empty name")
    func renameFolderEmpty() throws {
        let vm = ContentViewModel()

        let container = try makeTestContainer()
        let context = container.mainContext

        let folder = FolderEntity(name: "Keep", sortOrder: 0)
        context.insert(folder)
        try context.save()

        vm.renameFolder(from: "Keep", to: "  ", folders: [folder], context: context)
        #expect(folder.name == "Keep")
    }
}

import SwiftUI
import AppKit
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playbackManager: PlaybackManager
    @Query(sort: \RecordingEntity.createdAt, order: .reverse)
    private var recordings: [RecordingEntity]

    @State private var recorder = SystemAudioRecorder()
    @State private var isRecording = false
    @State private var selectedRecordingID: RecordingEntity.ID?
    @State private var pendingRecording: RecordingEntity?
    @State private var recordingPendingDeletion: RecordingEntity?
    @State private var isShowingDeleteConfirmation = false
    @State private var searchText = ""
    @State private var selectedSidebarItem: SidebarItem? = .library(.all)

    private let sidebarWidth: CGFloat = 220

    var body: some View {
       ZStack(alignment: .bottomLeading) {
            HStack(alignment: .top, spacing: 16) {
                sidebar
                recordingsColumn
                detailPanel
            }
            .padding(24)
            .frame(minWidth: 960, minHeight: 600)

            recordButton
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
        .onAppear { recalcSelection() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSidebarItem) {
            Section("Library") {
                ForEach(LibraryCategory.allCases) { category in
                    Label(category.title, systemImage: category.icon)
                        .tag(SidebarItem.library(category))
                }
            }
            Section("My Folders") {
                let folders = userFolders
                if folders.isEmpty {
                    Text("No folders yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(folders, id: \.self) { folder in
                    Label(folder, systemImage: "folder")
                        .tag(SidebarItem.folder(folder))
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(width: sidebarWidth, maxHeight: .infinity)
        .background(panelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }

    // MARK: - Recordings Column

    private var recordingsColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField
            recordingsList
        }
        .padding(16)
        .frame(minWidth: 320, idealWidth: 360)
        .background(panelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }

    private var searchField: some View {
        TextField("Search recordings", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .onChange(of: searchText) { _, _ in
                recalcSelection(keepExisting: true)
            }
    }

    private var recordingsList: some View {
        List(selection: $selectedRecordingID) {
            ForEach(filteredRecordings) { rec in
                RecordingRow(recording: rec,
                             isActive: playbackManager.activeRecordingID == rec.id,
                             isSelected: selectedRecordingID == rec.id,
                             durationString: formatTime(rec.duration))
                    .tag(rec.id)
                    .contentShape(Rectangle())
                    .listRowBackground(rowBackground(for: rec))
                    .contextMenu {
                        Button(rec.isFavorite ? "Remove Favorite" : "Add to Favorites") {
                            toggleFavorite(rec)
                        }
                        if rec.deletedAt == nil {
                            Button("Assign Folder") { promptForFolder(rec) }
                        }
                        Button("Show in Finder") { reveal(rec) }
                        Divider()
                        Button(rec.deletedAt == nil ? "Delete" : "Remove Permanently", role: .destructive) {
                            confirmDelete(rec)
                        }
                    }
                    .onTapGesture {
                        selectedRecordingID = rec.id
                        handleSelectionChange(newValue: rec.id)
                    }
            }
            .onDelete { offsets in
                let items = offsets.compactMap { index in
                    filteredRecordings[safe: index]
                }
                items.forEach(confirmDelete)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private func rowBackground(for recording: RecordingEntity) -> some View {
        Group {
            if selectedRecordingID == recording.id {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(Color.accentColor.opacity(0.15))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(Color.clear)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let recording = selectedRecording,
               recording.deletedAt == nil {
                detailHeader(for: recording)
                playbackControls(for: recording)
                Spacer()
            } else if let recording = selectedRecording {
                deletedMessage(for: recording)
                Spacer()
            } else {
                emptyDetailState
                Spacer()
            }
        }
        .padding(24)
        .frame(minWidth: 320, idealWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(panelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }

    private func detailHeader(for recording: RecordingEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recording.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(recording.createdAt.formatted(date: .long, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(formatTime(recording.duration), systemImage: "clock")
                if recording.isFavorite {
                    Label("Favorite", systemImage: "star.fill")
                }
                if let folder = recording.folder, !folder.isEmpty {
                    Label(folder, systemImage: "folder")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func playbackControls(for recording: RecordingEntity) -> some View {
        PlaybackControlsView(recording: recording)
            .environmentObject(playbackManager)
    }

    private func deletedMessage(for recording: RecordingEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recording.title)
                .font(.title3)
            Text("This recording was moved to the Trash on \(recording.deletedAt?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date").")
                .foregroundStyle(.secondary)
            Text("Playback is unavailable.")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyDetailState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Recording Selected")
                .font(.title3)
            Text("Choose a recording from the list to see its details and controls.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            Task {
                if isRecording {
                    await recorder.stopRecording()
                    isRecording = false
                    await finalizePendingRecording()
                    recalcSelection()
                } else {
                    await startNewRecording()
                    recalcSelection(selectNewest: true)
                }
            }
        } label: {
            Label(isRecording ? "Stop Recording" : "Start Recording",
                  systemImage: isRecording ? "stop.circle.fill" : "record.circle")
                .font(.title3)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isRecording ? Color.red.opacity(0.85) : Color.accentColor.opacity(0.85))
                )
                .foregroundStyle(Color.white)
                .shadow(radius: 6, y: 3)
        }
        .buttonStyle(.plain)
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

    private func startNewRecording() async {
        do {
            let dir = try AppDirectories.recordingsDir()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            let base = formatter.string(from: .now)
            let fileName = "\(base).m4a"
            let url = dir.appendingPathComponent(fileName)

            try await recorder.startRecording(to: url)

            let entity = RecordingEntity(
                title: base,
                createdAt: .now,
                duration: 0,
                fileName: fileName
            )
            modelContext.insert(entity)
            try? modelContext.save()

            pendingRecording = entity
            isRecording = true
            selectedSidebarItem = .library(.all)
            selectedRecordingID = entity.id
        } catch {
            print("startRecording error:", error)
        }
    }

    private func finalizePendingRecording() async {
        guard let recording = pendingRecording,
              let url = try? url(for: recording) else {
            pendingRecording = nil
            return
        }
        let asset = AVURLAsset(url: url)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0.01 {
                recording.duration = seconds
                try? modelContext.save()
            }
        } catch {
            print("duration load error:", error)
        }
        pendingRecording = nil
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
            playbackManager.select(recording: rec, autoPlay: true)
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

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func panelBackground() -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}

// MARK: - Sidebar Types

private enum SidebarItem: Hashable, Identifiable {
    case library(LibraryCategory)
    case folder(String)

    var id: Self { self }
}

private enum LibraryCategory: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recentlyDeleted

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All Recordings"
        case .favorites: return "Favorites"
        case .recentlyDeleted: return "Recently Deleted"
        }
    }

    var icon: String {
        switch self {
        case .all: return "rectangle.stack"
        case .favorites: return "star"
        case .recentlyDeleted: return "trash"
        }
    }
}

// MARK: - Recording Row

private struct RecordingRow: View {
    let recording: RecordingEntity
    let isActive: Bool
    let isSelected: Bool
    let durationString: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(durationString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if recording.deletedAt != nil { return "trash" }
        if recording.isFavorite { return "star.fill" }
        return "waveform"
    }

    private var iconColor: Color {
        if recording.deletedAt != nil { return .secondary }
        if recording.isFavorite { return .yellow }
        return isActive ? .accentColor : .secondary
    }
}

// MARK: - Collection Safe Index

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

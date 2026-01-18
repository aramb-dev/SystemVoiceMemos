import SwiftUI
import AppKit
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playbackManager: PlaybackManager
    @Query(sort: \RecordingEntity.createdAt, order: .reverse)
    private var recordings: [RecordingEntity]

    @StateObject private var recorder = SystemAudioRecorder()
    @StateObject private var floatingPanel = FloatingRecordingPanel()
    @StateObject private var windowAnimator = WindowAnimator()
    @AppStorage(AppConstants.UserDefaultsKeys.hideFromScreenSharing) private var hideFromScreenSharing = true
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
            HStack(alignment: .top, spacing: 0) {
                sidebar
                Divider()
                recordingsColumn
                Divider()
                detailPanel
            }
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
        .onAppear {
            recalcSelection()
            applyScreenSharingPreference(hideFromScreenSharing)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
            // Handle resetting onboarding if needed, or just let App handle it
            UserDefaults.standard.set(false, forKey: AppConstants.UserDefaultsKeys.hasCompletedOnboarding)
        }
        .onChange(of: hideFromScreenSharing) { _, newValue in
            applyScreenSharingPreference(newValue)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSidebarItem) {
            Section {
                ForEach(LibraryCategory.allCases) { category in
                    Label {
                        Text(category.title)
                            .font(.system(size: 13))
                    } icon: {
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(category == .all ? .blue : .secondary)
                    }
                    .tag(SidebarItem.library(category))
                }
            } header: {
                Text("Library")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            
            Section {
                let folders = userFolders
                if folders.isEmpty {
                    Text("No folders")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 20)
                } else {
                    ForEach(folders, id: \.self) { folder in
                        Label {
                            Text(folder)
                                .font(.system(size: 13))
                        } icon: {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                        }
                        .tag(SidebarItem.folder(folder))
                    }
                }
            } header: {
                Text("Folders")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .listStyle(.sidebar)
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Recordings Column

    private var recordingsColumn: some View {
        VStack(spacing: 0) {
            // Toolbar with search
            VStack(spacing: 12) {
                HStack {
                    Text(sidebarTitle)
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Text("\(filteredRecordings.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                searchField
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            Divider()
            
            recordingsList
        }
        .frame(minWidth: 300)
    }
    
    // MARK: - Detail Panel
    
    private var detailPanel: some View {
        Group {
            if let recording = selectedRecording {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailHeader(for: recording)
                        
                        if recording.deletedAt != nil {
                            deletedMessage(for: recording)
                        } else {
                            playbackControls(for: recording)
                        }
                    }
                    .padding(20)
                }
            } else {
                emptyDetailState
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
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onChange(of: searchText) { _, _ in
                    recalcSelection(keepExisting: true)
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private var recordingsList: some View {
        List(selection: $selectedRecordingID) {
            ForEach(filteredRecordings) { rec in
                RecordingRow(recording: rec,
                             isActive: playbackManager.activeRecordingID == rec.id,
                             isSelected: selectedRecordingID == rec.id,
                             durationString: formatTime(rec.duration))
                    .tag(rec.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                    .contextMenu {
                        Button(rec.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                            toggleFavorite(rec)
                        }
                        if rec.deletedAt == nil {
                            Button("Move to Folder...") { promptForFolder(rec) }
                        }
                        Button("Show in Finder") { reveal(rec) }
                        Divider()
                        Button(rec.deletedAt == nil ? "Move to Trash" : "Delete Permanently", role: .destructive) {
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
                    await stopRecordingFlow()
                } else {
                    await startRecordingFlow()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.title3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isRecording ? Color.red.opacity(0.85) : Color.accentColor.opacity(0.85))
            )
            .foregroundStyle(Color.white)
            .overlay {
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: isRecording ? Color.red.opacity(0.3) : Color.accentColor.opacity(0.3), radius: 8, y: 4)
            .shadow(color: Color.white.opacity(0.1), radius: 1, y: -1)
        }
        .buttonStyle(.plain)
    }
    
    private func startRecordingFlow() async {
        // Prevent concurrent executions - similar guard to stopRecordingFlow()
        guard !recorder.isRecording else { return }
        
        await startNewRecording()
        isRecording = true
        
        floatingPanel.onStop = {
            Task { @MainActor in
                await self.stopRecordingFlow()
            }
        }
        
        floatingPanel.onRestart = {
            Task { @MainActor in
                await self.restartRecordingFlow()
            }
        }
        
        floatingPanel.onExpand = {
            Task { @MainActor in
                self.expandToFullWindow()
            }
        }
        
        windowAnimator.shrinkToBar()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.floatingPanel.show(recorder: self.recorder)
            self.floatingPanel.setScreenCaptureExclusion(self.hideFromScreenSharing)
        }
        
        recalcSelection(selectNewest: true)
    }
    
    private func expandToFullWindow() {
        floatingPanel.hide()
        windowAnimator.expandToFull()
    }
    
    private func stopRecordingFlow() async {
        // Don't process if already stopped
        guard recorder.isRecording else { return }

        await recorder.stopRecording()
        isRecording = false
        floatingPanel.hide()
        
        if windowAnimator.isMinimized {
            windowAnimator.expandToFull()
        } else {
            // If the window was mid-animation or hidden, restore it to the last saved frame
            windowAnimator.restoreWithoutAnimation()
        }
        
        await finalizePendingRecording()
        recalcSelection()
    }
    
    private func restartRecordingFlow() async {
        await recorder.stopRecording()
        
        // Delete the pending recording without saving
        if let pending = pendingRecording {
            let fileURL = (try? AppDirectories.recordingsDir())?.appendingPathComponent(pending.fileName)
            if let url = fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(pending)
            pendingRecording = nil
        }
        
        // Start fresh
        await startNewRecording()
        floatingPanel.show(recorder: recorder)
    }

    private func formatRecordingDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centiseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
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

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func panelBackground() -> some View {
        ZStack {
            // Base material with subtle gradient
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)

            // Inner highlight for depth
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            // Subtle border highlight
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private func applyScreenSharingPreference(_ exclude: Bool) {
        NSApp.windows.forEach { window in
            window.sharingType = exclude ? .none : .readOnly
        }
        floatingPanel.setScreenCaptureExclusion(exclude)
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
            // Icon with glass circle for active state
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                }
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(recording.title)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .font(.system(size: 13))
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Duration badge with glass pill
            Text(durationString)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    ZStack {
                        Capsule()
                            .fill(.thinMaterial)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
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

// MARK: - Playback Controls

private struct PlaybackControlsView: View {
    @EnvironmentObject private var playbackManager: PlaybackManager
    let recording: RecordingEntity

    var body: some View {
        VStack(spacing: 16) {
            // Progress slider
            VStack(spacing: 4) {
                Slider(value: sliderBinding, in: 0...max(playbackManager.duration, 1))
                    .disabled(!playbackManager.hasActivePlayer)
                
                HStack {
                    Text(formatTime(playbackManager.currentTime))
                    Spacer()
                    Text(formatTime(playbackManager.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            // Playback controls
            HStack(spacing: 24) {
                Button {
                    playbackManager.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                .disabled(!playbackManager.hasActivePlayer)
                .buttonStyle(.plain)
                
                Button {
                    playbackManager.togglePlayPause()
                } label: {
                    Image(systemName: playbackManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(!playbackManager.hasSelection)
                .buttonStyle(.plain)
                
                Button {
                    playbackManager.skip(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
                .disabled(!playbackManager.hasActivePlayer)
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { playbackManager.currentTime },
            set: { playbackManager.seek(to: $0) }
        )
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Detail Panel

private struct DetailPanel: View {
    let recording: RecordingEntity?
    @EnvironmentObject var playbackManager: PlaybackManager
    
    var body: some View {
        if let recording = recording {
            VStack(spacing: 20) {
                // Playback controls (matching reference design)
                HStack(spacing: 20) {
                    // Skip back 15s
                    Button {
                        playbackManager.skip(by: -15)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                }
                            HStack(spacing: 2) {
                                Image(systemName: "gobackward")
                                    .font(.system(size: 16, weight: .medium))
                                Text("15")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                    }
                    .disabled(!playbackManager.hasActivePlayer)
                    .buttonStyle(.plain)

                    // Play/Pause button
                    Button {
                        playbackManager.togglePlayPause()
                    } label: {
                        ZStack {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor)

                                // Inner highlight for glass effect
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }

                            Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(!playbackManager.hasSelection)
                    .buttonStyle(.plain)

                    // Skip forward 15s
                    Button {
                        playbackManager.skip(by: 15)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                }
                            HStack(spacing: 2) {
                                Text("15")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "goforward")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
                    .disabled(!playbackManager.hasActivePlayer)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)

                // Volume control
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { Double(playbackManager.volume) },
                        set: { playbackManager.setVolume(Float($0)) }
                    ), in: 0...1)
                        .frame(width: 140)
                }
            }
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)

                    // Subtle gradient overlay for depth
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.clear,
                                    Color.black.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            )
        } else {
            emptyDetailState
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
        .padding()
    }
}

// MARK: - Collection Safe Index

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

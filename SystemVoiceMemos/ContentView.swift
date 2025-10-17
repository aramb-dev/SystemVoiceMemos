import SwiftUI
import AppKit
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playbackManager: PlaybackManager
    // 👇 Explicit root type fixes “Cannot infer key path type…”
    @Query(sort: \RecordingEntity.createdAt, order: .reverse)
    private var recordings: [RecordingEntity]

    @State private var recorder = SystemAudioRecorder()
    @State private var isRecording = false
    @State private var selectedRecordingID: RecordingEntity.ID?
    @State private var pendingRecording: RecordingEntity?
    @State private var recordingPendingDeletion: RecordingEntity?
    @State private var isShowingDeleteConfirmation = false

    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controlHeader
            recordingsList
            PlaybackControlsView(recording: selectedRecording)
                .environmentObject(playbackManager)
        }
        .padding()
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
    }

    private var controlHeader: some View {
        HStack(spacing: 12) {
            Button(isRecording ? "Stop Recording" : "Start Recording") {
                Task {
                    if isRecording {
                        await recorder.stopRecording()
                        isRecording = false
                        await finalizePendingRecording()
                    } else {
                        await startNewRecording()
                    }
                }
            }
            Button("Open Folder") { openFolder() }
        }
    }

    private var recordingsList: some View {
        List(selection: $selectedRecordingID) {
            ForEach(recordings) { rec in
                RecordingRow(recording: rec,
                             isActive: playbackManager.activeRecordingID == rec.id,
                             isSelected: selectedRecordingID == rec.id,
                             durationString: formatTime(rec.duration),
                             revealAction: { reveal(rec) },
                             deleteAction: { confirmDelete(rec) })
                    .tag(rec.id)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Show in Finder") { reveal(rec) }
                        Button("Delete", role: .destructive) { confirmDelete(rec) }
                    }
            }
            .onDelete(perform: delete(offsets:))
        }
        .frame(minHeight: 320)
        .onChange(of: selectedRecordingID) { _, newValue in
            handleSelectionChange(newValue: newValue)
        }
    }

    private var selectedRecording: RecordingEntity? {
        guard let selectedRecordingID else { return nil }
        return recordings.first(where: { $0.id == selectedRecordingID })
    }

    private var recordingsHash: Int {
        recordings.reduce(into: 0) { partialResult, recording in
            partialResult ^= recording.id.hashValue
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
        playbackManager.select(recording: rec, autoPlay: true)
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

    private func reveal(_ rec: RecordingEntity) {
        if let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            NSWorkspace.shared.activateFileViewerSelecting([url])
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

        if let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                print("trashItem error:", error)
            }
        }

        if selectedRecordingID == rec.id {
            selectedRecordingID = nil
        }
        playbackManager.handleDeletion(of: rec.id)
        modelContext.delete(rec)
        try? modelContext.save()
    }

    private func delete(offsets: IndexSet) {
        guard let index = offsets.first else { return }
        confirmDelete(recordings[index])
    }

    private func openFolder() {
        if let dir = try? AppDirectories.recordingsDir() {
            NSWorkspace.shared.open(dir)
        }
    }

    private func url(for recording: RecordingEntity) throws -> URL {
        let dir = try AppDirectories.recordingsDir()
        return dir.appendingPathComponent(recording.fileName)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

private struct RecordingRow: View {
    let recording: RecordingEntity
    let isActive: Bool
    let isSelected: Bool
    let durationString: String
    let revealAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "waveform.circle.fill" : "waveform.circle")
                .foregroundStyle(isActive ? .blue : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .fontWeight(isActive ? .semibold : .regular)
                Text(recording.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(durationString)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Show in Finder", action: revealAction)
                .buttonStyle(.borderless)
            Button(role: .destructive, action: deleteAction) {
                Text("Delete")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

private struct PlaybackControlsView: View {
    @EnvironmentObject private var playbackManager: PlaybackManager
    let recording: RecordingEntity?

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let recording {
                HStack {
                    Text(recording.title)
                        .font(.headline)
                    Spacer()
                    Text(formatTime(playbackManager.duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        playbackManager.togglePlayPause()
                    } label: {
                        Label(playbackManager.isPlaying ? "Pause" : "Play",
                              systemImage: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(!playbackManager.hasSelection)

                    Button {
                        playbackManager.skip(by: -15)
                    } label: {
                        Label("-15s", systemImage: "gobackward.15")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!playbackManager.hasActivePlayer)

                    Button {
                        playbackManager.skip(by: 15)
                    } label: {
                        Label("+15s", systemImage: "goforward.15")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!playbackManager.hasActivePlayer)

                    Button {
                        playbackManager.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(!playbackManager.hasActivePlayer)

                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: sliderBinding,
                               in: 0...(playbackManager.duration > 0 ? playbackManager.duration : 1))
                            .disabled(playbackManager.duration <= 0)
                        HStack {
                            Text(formatTime(playbackManager.currentTime))
                            Spacer()
                            let remaining = max(playbackManager.duration - playbackManager.currentTime, 0)
                            Text("-" + formatTime(remaining))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { Double(playbackManager.volume) },
                            set: { playbackManager.setVolume(Float($0)) }
                        ), in: 0...1)
                            .frame(width: 120)
                    }
                }
            } else {
                Text("Select a recording to play")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical)
    }
}

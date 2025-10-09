import SwiftUI
import AppKit
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // 👇 Explicit root type fixes “Cannot infer key path type…”
    @Query(sort: \RecordingEntity.createdAt, order: .reverse)
    private var recordings: [RecordingEntity]

    @State private var recorder = SystemAudioRecorder()
    @State private var isRecording = false

    // 👇 Ensure the app can call ContentView() without parameters
    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(isRecording ? "Stop Recording" : "Start Recording") {
                    Task {
                        if isRecording {
                            await recorder.stopRecording()
                            isRecording = false
                        } else {
                            do {
                                let dir = try AppDirectories.recordingsDir()
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                                let base = formatter.string(from: .now)
                                let fileName = "\(base).m4a"
                                let url = dir.appendingPathComponent(fileName)

                                try await recorder.startRecording(to: url)

                                // Insert SwiftData row
                                let entity = RecordingEntity(
                                    title: base,
                                    createdAt: .now,
                                    duration: 0,
                                    fileName: fileName
                                )
                                modelContext.insert(entity)
                                try? modelContext.save()

                                isRecording = true
                            } catch {
                                print("startRecording error:", error)
                            }
                        }
                    }
                }
                Button("Open Folder") { openFolder() }
            }

            List {
                ForEach(recordings) { rec in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rec.title).bold()
                            Text(rec.createdAt.formatted(date: .numeric, time: .standard))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Show in Finder") { reveal(rec) }
                        Button(role: .destructive) { delete(rec) } label: { Text("Delete") }
                    }
                }
                .onDelete(perform: delete(offsets:))
            }
            .frame(minHeight: 320)
        }
        .padding()
    }

    // MARK: - Actions

    private func reveal(_ rec: RecordingEntity) {
        if let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // Removed unnecessary do/catch (nothing here throws)
    private func delete(_ rec: RecordingEntity) {
        if let dir = try? AppDirectories.recordingsDir() {
            let url = dir.appendingPathComponent(rec.fileName)
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(rec)
        try? modelContext.save()
    }

    private func delete(offsets: IndexSet) {
        for index in offsets { delete(recordings[index]) }
    }

    private func openFolder() {
        if let dir = try? AppDirectories.recordingsDir() {
            NSWorkspace.shared.open(dir)
        }
    }
}

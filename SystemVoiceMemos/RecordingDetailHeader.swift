//
//  RecordingDetailHeader.swift
//  SystemVoiceMemos
//

import SwiftUI

struct RecordingDetailHeader: View {
    let recording: RecordingEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recording.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(recording.createdAt.formatted(date: .long, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(TimeFormatter.format(recording.duration), systemImage: "clock")
                if recording.isFavorite {
                    Label("Favorite", systemImage: "star.fill")
                }
                if let folder = recording.folderName, !folder.isEmpty {
                    Label(folder, systemImage: "folder")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct DeletedRecordingMessage: View {
    let recording: RecordingEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recording.title)
                .font(.title3)
            Text("This recording was moved to the Trash on \(recording.deletedAt?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date").")
                .foregroundStyle(.secondary)
            Text("Playback is unavailable.")
                .foregroundStyle(.secondary)
        }
    }
}

struct EmptyDetailState: View {
    var body: some View {
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
}

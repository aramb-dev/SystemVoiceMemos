//
//  RecordingsListView.swift
//  SystemVoiceMemos
//

import SwiftUI

struct RecordingsListView: View {
    let title: String
    let category: LibraryCategory?
    let recordings: [RecordingEntity]
    @Binding var selectedRecordingID: RecordingEntity.ID?
    @Binding var searchText: String

    let activeRecordingID: UUID?
    let onSelect: (RecordingEntity.ID?) -> Void
    let onToggleFavorite: (RecordingEntity) -> Void
    let onMoveToFolder: (RecordingEntity) -> Void
    let onReveal: (RecordingEntity) -> Void
    let onDelete: (RecordingEntity) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Text("\(recordings.count)")
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

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
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
        Group {
            if recordings.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(recordings) { rec in
                        recordingRowView(for: rec)
                    }
                    .onDelete { offsets in
                        offsets.compactMap { recordings[safe: $0] }.forEach(onDelete)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func recordingRowView(for rec: RecordingEntity) -> some View {
        RecordingRow(
            recording: rec,
            isActive: activeRecordingID == rec.id,
            isSelected: selectedRecordingID == rec.id,
            durationString: rec.isCloudOnly && rec.duration <= 0 ? "--:--" : TimeFormatter.format(rec.duration)
        )
        .tag(rec.id)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
        .contentShape(Rectangle())
        .contextMenu {
            Button(rec.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                onToggleFavorite(rec)
            }
            if rec.deletedAt == nil {
                Button("Move to Folder...") { onMoveToFolder(rec) }
            }
            Button("Show in Finder") { onReveal(rec) }
            Divider()
            Button(rec.deletedAt == nil ? "Move to Trash" : "Delete Permanently", role: .destructive) {
                onDelete(rec)
            }
        }
        .onTapGesture {
            if selectedRecordingID == rec.id {
                selectedRecordingID = nil
                onSelect(nil)
            } else {
                selectedRecordingID = rec.id
                onSelect(rec.id)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(emptyStateTitle)
                .font(.system(size: 14, weight: .semibold))

            Text(emptyStateMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 220)

            if !searchText.isEmpty {
                Button("Clear Search") {
                    searchText = ""
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.link)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var emptyStateIcon: String {
        if !searchText.isEmpty { return "magnifyingglass" }
        switch category {
        case .favorites: return "star"
        case .recentlyDeleted: return "trash"
        default: return "waveform"
        }
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty { return "No Matches" }
        switch category {
        case .favorites: return "No Favorites Yet"
        case .recentlyDeleted: return "Trash Is Empty"
        default: return "No Recordings Yet"
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try a different search or clear the field to see every recording in this view."
        }
        switch category {
        case .favorites:
            return "Mark recordings with the star button to keep important clips close."
        case .recentlyDeleted:
            return "Deleted recordings will appear here before they are removed permanently."
        default:
            return "Press the record button to capture your first system audio memo."
        }
    }
}

// MARK: - Collection Safe Index

extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

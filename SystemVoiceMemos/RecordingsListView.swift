//
//  RecordingsListView.swift
//  SystemVoiceMemos
//

import SwiftUI

struct RecordingsListView: View {
    let title: String
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
        List(selection: $selectedRecordingID) {
            ForEach(recordings) { rec in
                RecordingRow(
                    recording: rec,
                    isActive: activeRecordingID == rec.id,
                    isSelected: selectedRecordingID == rec.id,
                    durationString: TimeFormatter.format(rec.duration)
                )
                .tag(rec.id)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
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
                    selectedRecordingID = rec.id
                    onSelect(rec.id)
                }
            }
            .onDelete { offsets in
                offsets.compactMap { recordings[safe: $0] }.forEach(onDelete)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Collection Safe Index

extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

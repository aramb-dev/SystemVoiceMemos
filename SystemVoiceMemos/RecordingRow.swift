//
//  RecordingRow.swift
//  SystemVoiceMemos
//

import SwiftUI

struct RecordingRow: View {
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
        if recording.isCloudOnly { return "icloud.and.arrow.down" }
        if recording.isFavorite { return "star.fill" }
        return "waveform"
    }

    private var iconColor: Color {
        if recording.deletedAt != nil { return .secondary }
        if recording.isCloudOnly { return .blue }
        if recording.isFavorite { return .yellow }
        return isActive ? .accentColor : .secondary
    }
}

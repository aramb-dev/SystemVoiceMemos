//
//  RecordButtonView.swift
//  SystemVoiceMemos
//

import SwiftUI

struct RecordButtonView: View {
    let isRecording: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
        .accessibilityLabel(isRecording ? "Stop Recording" : "Start Recording")
    }
}

#Preview {
    VStack(spacing: 20) {
        RecordButtonView(isRecording: false) {}
        RecordButtonView(isRecording: true) {}
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

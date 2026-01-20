//
//  DetailPanel.swift
//  SystemVoiceMemos
//

import SwiftUI

struct DetailPanel: View {
    let recording: RecordingEntity?
    @EnvironmentObject var playbackManager: PlaybackManager
    
    var body: some View {
        if recording != nil {
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

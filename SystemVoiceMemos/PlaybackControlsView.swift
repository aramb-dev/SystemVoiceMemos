//
//  PlaybackControlsView.swift
//  SystemVoiceMemos
//

import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject private var playbackManager: PlaybackManager
    @StateObject private var waveformAnalyzer = WaveformAnalyzer()
    let recording: RecordingEntity

    var body: some View {
        VStack(spacing: 16) {
            // Waveform visualization
            waveformSection
            
            // Seek slider
            Slider(value: sliderBinding, in: 0...max(playbackManager.duration, 1))
                .disabled(!playbackManager.hasActivePlayer)
            
            // Time labels
            HStack {
                Text(formatTime(playbackManager.currentTime))
                Spacer()
                Text(formatTime(playbackManager.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
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
        .task(id: recording.id) {
            await loadWaveform()
        }
    }
    
    @ViewBuilder
    private var waveformSection: some View {
        if waveformAnalyzer.isAnalyzing && waveformAnalyzer.waveformData.isEmpty {
            LoadingWaveformView()
        } else if !waveformAnalyzer.waveformData.isEmpty {
            WaveformView(
                waveformData: waveformAnalyzer.waveformData,
                currentTime: playbackManager.currentTime,
                duration: playbackManager.duration > 0 ? playbackManager.duration : recording.duration,
                onSeek: { time in
                    playbackManager.seek(to: time)
                },
                isPlaceholder: !waveformAnalyzer.hasRealData
            )
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            )
        } else {
            // Fallback slider
            Slider(value: sliderBinding, in: 0...max(playbackManager.duration, 1))
                .disabled(!playbackManager.hasActivePlayer)
        }
    }
    
    private func loadWaveform() async {
        guard let recordingsDir = try? AppDirectories.recordingsDir() else { return }
        let url = recordingsDir.appendingPathComponent(recording.fileName)
        await waveformAnalyzer.analyzeAudioFile(at: url, duration: recording.duration)
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

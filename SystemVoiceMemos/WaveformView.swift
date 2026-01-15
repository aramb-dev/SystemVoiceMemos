//
//  WaveformView.swift
//  SystemVoiceMemos
//
//  Created by aramb-dev on 10/8/25.
//

import SwiftUI

// MARK: - Loading State View

struct LoadingWaveformView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Analyzing audio...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Main Waveform View

struct WaveformView: View {
    let waveformData: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    let isPlaceholder: Bool

    @State private var isDragging = false

    private let waveformHeight: CGFloat = 100
    private let timelineHeight: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            // Main waveform display
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Unplayed portion (full waveform, dimmed)
                    filledWaveform(progress: 1.0, color: waveformUnplayedColor)
                        .frame(height: waveformHeight)

                    // Played portion (overlay, brighter)
                    filledWaveform(progress: playbackProgress, color: waveformPlayedColor)
                        .frame(height: waveformHeight)

                    // Playhead
                    playheadView(in: geometry)
                }
                .frame(height: waveformHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            onSeek(newTime)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: waveformHeight)

            // Timeline with time markers
            timelineView
        }
    }

    private var playbackProgress: CGFloat {
        duration > 0 ? min(1, currentTime / duration) : 0
    }

    private func filledWaveform(progress: CGFloat, color: Color) -> some View {
        GeometryReader { geometry in
            let dataCount = max(1, waveformData.count)
            let barWidth = geometry.size.width / CGFloat(dataCount)

            // Create a filled waveform path (always full width)
            let path = Path { path in
                let halfHeight = waveformHeight / 2

                // Start at bottom-left
                path.move(to: CGPoint(x: 0, y: waveformHeight))

                // Draw the top edge of the waveform
                for i in 0..<dataCount {
                    let amplitude = CGFloat(waveformData[i])
                    let x = CGFloat(i) * barWidth + barWidth / 2
                    let barHeight = max(2, amplitude * halfHeight * 1.8)
                    let y = halfHeight - barHeight / 2
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                // Draw the bottom edge back to start (mirrored)
                for i in stride(from: dataCount - 1, through: 0, by: -1) {
                    let amplitude = CGFloat(waveformData[i])
                    let x = CGFloat(i) * barWidth + barWidth / 2
                    let barHeight = max(2, amplitude * halfHeight * 1.8)
                    let y = halfHeight + barHeight / 2
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                // Close the path
                path.closeSubpath()
            }

            // Clip to the progress width
            path.fill(color)
                .clipShape(
                    Rectangle()
                        .size(width: geometry.size.width * progress, height: waveformHeight)
                )
        }
    }

    private var waveformPlayedColor: Color {
        isPlaceholder ? Color.white.opacity(0.7) : Color.white
    }

    private var waveformUnplayedColor: Color {
        isPlaceholder ? Color.white.opacity(0.25) : Color.white.opacity(0.3)
    }

    private func playheadView(in geometry: GeometryProxy) -> some View {
        let xPosition = playbackProgress * geometry.size.width

        return Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2)
            .position(x: xPosition, y: waveformHeight / 2)
            .animation(.easeInOut(duration: 0.08), value: playbackProgress)
    }
    
    private var timelineView: some View {
        GeometryReader { geometry in
            HStack {
                ForEach(timelineMarkers, id: \.self) { second in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 1, height: 8)

                        Text(formatTimelineLabel(second))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: timelineHeight)
    }

    // Generate smart timeline markers (max 20 ticks)
    private var timelineMarkers: [Int] {
        let totalSeconds = Int(duration.rounded())
        guard totalSeconds > 0 else { return [0] }

        // Maximum number of timeline markers to display
        let maxMarkers = 20

        // If duration is short enough, show all seconds
        if totalSeconds <= maxMarkers {
            return Array(0...totalSeconds)
        }

        // Calculate interval to show approximately maxMarkers
        // Use nice intervals: 5, 10, 15, 30, 60, 120, 300, 600, etc.
        let niceIntervals = [5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600]
        let targetInterval = totalSeconds / maxMarkers

        let interval = niceIntervals.first { $0 >= targetInterval } ?? niceIntervals.last!

        // Generate markers at the chosen interval
        var markers: [Int] = []
        var current = 0
        while current <= totalSeconds {
            markers.append(current)
            current += interval
        }

        return markers
    }

    private func formatTimelineLabel(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let secs = seconds % 60
            if secs == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes):\(String(format: "%02d", secs))"
            }
        }
    }
    
}

struct OverviewWaveformView: View {
    let waveformData: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    let isPlaceholder: Bool

    @State private var isDragging = false

    private let overviewHeight: CGFloat = 32

    var body: some View {
        HStack(spacing: 0) {
            // Waveform overview
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Unplayed portion (dimmed)
                    filledWaveform(progress: 1.0, color: waveformUnplayedColor)

                    // Played portion (brighter)
                    filledWaveform(progress: playbackProgress, color: waveformPlayedColor)

                    // Playhead indicator
                    playheadIndicator(in: geometry)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            let newTime = progress * duration
                            onSeek(newTime)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: overviewHeight)

            // Duration label
            Text(formatTime(duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
    }

    private var playbackProgress: CGFloat {
        duration > 0 ? min(1, currentTime / duration) : 0
    }

    private func filledWaveform(progress: CGFloat, color: Color) -> some View {
        GeometryReader { geometry in
            let dataCount = max(1, waveformData.count)
            let barWidth = geometry.size.width / CGFloat(dataCount)

            // Create a filled waveform path (always full width)
            let path = Path { path in
                let halfHeight = overviewHeight / 2

                // Start at bottom-left
                path.move(to: CGPoint(x: 0, y: overviewHeight))

                // Draw the top edge
                for i in 0..<dataCount {
                    let amplitude = CGFloat(waveformData[i])
                    let x = CGFloat(i) * barWidth + barWidth / 2
                    let barHeight = max(1, amplitude * halfHeight * 1.6)
                    let y = halfHeight - barHeight / 2
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                // Draw the bottom edge back to start (mirrored)
                for i in stride(from: dataCount - 1, through: 0, by: -1) {
                    let amplitude = CGFloat(waveformData[i])
                    let x = CGFloat(i) * barWidth + barWidth / 2
                    let barHeight = max(1, amplitude * halfHeight * 1.6)
                    let y = halfHeight + barHeight / 2
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.closeSubpath()
            }

            // Clip to the progress width
            path.fill(color)
                .clipShape(
                    Rectangle()
                        .size(width: geometry.size.width * progress, height: overviewHeight)
                )
        }
    }

    private var waveformPlayedColor: Color {
        isPlaceholder ? Color.white.opacity(0.7) : Color.white
    }

    private var waveformUnplayedColor: Color {
        isPlaceholder ? Color.white.opacity(0.25) : Color.white.opacity(0.3)
    }

    private func playheadIndicator(in geometry: GeometryProxy) -> some View {
        let xPosition = playbackProgress * geometry.size.width

        return Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2)
            .position(x: xPosition, y: overviewHeight / 2)
            .animation(.easeInOut(duration: 0.08), value: playbackProgress)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingWaveformView()
            .frame(height: 100)

        WaveformView(
            waveformData: Array(0..<100).map { _ in Float.random(in: 0.2...1) },
            currentTime: 15.5,
            duration: 60.0,
            onSeek: { _ in },
            isPlaceholder: false
        )
        .frame(height: 120)

        OverviewWaveformView(
            waveformData: Array(0..<100).map { _ in Float.random(in: 0.2...1) },
            currentTime: 15.5,
            duration: 60.0,
            onSeek: { _ in },
            isPlaceholder: false
        )
        .frame(height: 32)
    }
    .padding()
    .background(Color.black)
}
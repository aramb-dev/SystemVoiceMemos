//
//  WaveformView.swift
//  SystemVoiceMemos
//
//  Created by aramb-dev on 10/8/25.
//

import SwiftUI

struct WaveformView: View {
    let waveformData: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    let isPlaceholder: Bool
    
    @State private var isDragging = false
    
    private let waveformHeight: CGFloat = 120
    private let timelineHeight: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 0) {
            // Main waveform display
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Waveform background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: waveformHeight)
                    
                    // Waveform bars
                    if !waveformData.isEmpty {
                        HStack(spacing: 1) {
                            ForEach(Array(waveformData.enumerated()), id: \.offset) { index, amplitude in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(waveformColor(for: index))
                                    .frame(width: 2, height: max(1, CGFloat(amplitude) * waveformHeight))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Playhead
                    playheadView(in: geometry)
                }
                .frame(height: waveformHeight)
                .clipped()
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
    
    private func playheadView(in geometry: GeometryProxy) -> some View {
        let progress = duration > 0 ? currentTime / duration : 0
        let xPosition = progress * geometry.size.width
        
        return Rectangle()
            .fill(Color.blue)
            .frame(width: 2)
            .position(x: xPosition, y: geometry.size.height / 2)
            .animation(.easeInOut(duration: 0.1), value: currentTime)
    }
    
    private var timelineView: some View {
        GeometryReader { geometry in
            HStack {
                ForEach(0..<Int(duration.rounded()) + 1, id: \.self) { second in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 1, height: 8)
                        
                        Text("\(second)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: timelineHeight)
    }
    
    private func waveformColor(for index: Int) -> Color {
        let progress = duration > 0 ? currentTime / duration : 0
        let dataIndex = Int(progress * Double(waveformData.count))
        
        if index <= dataIndex {
            return isPlaceholder ? Color.white.opacity(0.7) : Color.white
        } else {
            return isPlaceholder ? Color.gray.opacity(0.4) : Color.gray.opacity(0.6)
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
    
    var body: some View {
        HStack(spacing: 0) {
            // Waveform overview
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 30)
                    
                    // Waveform bars
                    if !waveformData.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(Array(waveformData.enumerated()), id: \.offset) { index, amplitude in
                                RoundedRectangle(cornerRadius: 0.5)
                                    .fill(waveformColor(for: index))
                                    .frame(width: 1, height: max(2, CGFloat(amplitude) * 26))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Playhead indicator
                    playheadIndicator(in: geometry)
                }
                .frame(height: 30)
                .clipped()
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
            
            // Duration label
            Text(formatTime(duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
    }
    
    private func playheadIndicator(in geometry: GeometryProxy) -> some View {
        let progress = duration > 0 ? currentTime / duration : 0
        let xPosition = progress * geometry.size.width
        
        return Rectangle()
            .fill(Color.blue)
            .frame(width: 2, height: 30)
            .position(x: xPosition, y: geometry.size.height / 2)
            .animation(.easeInOut(duration: 0.1), value: currentTime)
    }
    
    private func waveformColor(for index: Int) -> Color {
        let progress = duration > 0 ? currentTime / duration : 0
        let dataIndex = Int(progress * Double(waveformData.count))
        
        if index <= dataIndex {
            return isPlaceholder ? Color.white.opacity(0.7) : Color.white
        } else {
            return isPlaceholder ? Color.gray.opacity(0.4) : Color.gray.opacity(0.6)
        }
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
        WaveformView(
            waveformData: Array(0..<100).map { _ in Float.random(in: 0...1) },
            currentTime: 15.5,
            duration: 60.0,
            onSeek: { _ in },
            isPlaceholder: false
        )
        .frame(height: 140)
        
        OverviewWaveformView(
            waveformData: Array(0..<100).map { _ in Float.random(in: 0...1) },
            currentTime: 15.5,
            duration: 60.0,
            onSeek: { _ in },
            isPlaceholder: false
        )
        .frame(height: 30)
    }
    .padding()
    .background(Color.black)
}
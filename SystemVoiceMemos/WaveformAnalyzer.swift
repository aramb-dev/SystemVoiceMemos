//
//  WaveformAnalyzer.swift
//  SystemVoiceMemos
//
//  Created by aramb-dev on 10/8/25.
//

import Foundation
import AVFoundation
import Accelerate

@MainActor
class WaveformAnalyzer: ObservableObject {
    @Published var waveformData: [Float] = []
    @Published var isAnalyzing = false
    @Published var hasRealData = false

    private let analysisQueue = DispatchQueue(label: "waveform.analysis", qos: .userInitiated)
    private var currentAnalysisTask: Task<Void, Never>?
    
    func analyzeAudioFile(at url: URL, duration: TimeInterval) async {
        // Cancel any ongoing analysis
        currentAnalysisTask?.cancel()

        // Validate file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            await MainActor.run {
                self.waveformData = generatePlaceholderWaveform(duration: duration)
                self.hasRealData = false
                self.isAnalyzing = false
            }
            return
        }

        // First, show a placeholder waveform immediately
        await MainActor.run {
            self.waveformData = generatePlaceholderWaveform(duration: duration)
            self.hasRealData = false
            self.isAnalyzing = true
        }

        // Create a new analysis task
        currentAnalysisTask = Task {
            // Then analyze the real audio file in the background
            let realData = await withCheckedContinuation { continuation in
                analysisQueue.async {
                    let data = self.extractWaveformData(from: url)
                    continuation.resume(returning: data)
                }
            }

            // Check if task was cancelled before updating UI
            guard !Task.isCancelled else { return }

            // Update with real data when analysis is complete
            await MainActor.run {
                // Only update if we got valid data
                if !realData.isEmpty {
                    self.waveformData = realData
                    self.hasRealData = true
                }
                self.isAnalyzing = false
            }
        }

        await currentAnalysisTask?.value
    }
    
    private func generatePlaceholderWaveform(duration: TimeInterval) -> [Float] {
        // Generate a realistic-looking placeholder waveform
        let targetPoints = min(1000, Int(duration * 20)) // ~20 points per second
        var placeholder: [Float] = []
        placeholder.reserveCapacity(targetPoints)
        
        for i in 0..<targetPoints {
            // Create a more realistic waveform pattern
            let progress = Float(i) / Float(targetPoints)
            
            // Add some variation based on position
            let baseAmplitude: Float = 0.3 + 0.4 * sin(progress * .pi * 4) * cos(progress * .pi * 8)
            let noise = Float.random(in: -0.1...0.1)
            let variation = sin(progress * .pi * 12) * 0.2
            
            let amplitude = max(0.05, min(1.0, baseAmplitude + noise + variation))
            placeholder.append(amplitude)
        }
        
        return placeholder
    }
    
    private func extractWaveformData(from url: URL) -> [Float] {
        // Validate file exists before trying to open it
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ Waveform: File not found at \(url.path)")
            return []
        }

        // Try to open the audio file with proper error handling
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            print("⚠️ Waveform: Could not open audio file at \(url.path)")
            return []
        }

        let frameCount = UInt32(audioFile.length)
        guard frameCount > 0 else {
            print("⚠️ Waveform: Audio file has zero frames")
            return []
        }

        let bufferSize = 4096
        let samplesPerPixel = max(1, Int(frameCount) / 1000) // Aim for ~1000 data points

        var waveformData: [Float] = []
        waveformData.reserveCapacity(1000)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: UInt32(bufferSize)) else {
            print("⚠️ Waveform: Could not create PCM buffer")
            return []
        }

        var currentFrame: AVAudioFramePosition = 0
        var maxAmplitude: Float = 0
        var sampleCount = 0
        var readAttempts = 0
        let maxReadAttempts = Int(frameCount) / bufferSize + 10 // Safety limit

        while currentFrame < frameCount {
            // Safety check to prevent infinite loops
            readAttempts += 1
            if readAttempts > maxReadAttempts {
                print("⚠️ Waveform: Read attempts exceeded safety limit")
                break
            }

            do {
                try audioFile.read(into: buffer, frameCount: UInt32(bufferSize))

                guard let channelData = buffer.floatChannelData?[0] else {
                    print("⚠️ Waveform: No channel data available")
                    break
                }

                let actualFrameCount = Int(buffer.frameLength)
                guard actualFrameCount > 0 else {
                    // End of file reached
                    break
                }

                for i in 0..<actualFrameCount {
                    let amplitude = abs(channelData[i])
                    maxAmplitude = max(maxAmplitude, amplitude)
                    sampleCount += 1

                    if sampleCount >= samplesPerPixel {
                        waveformData.append(maxAmplitude)
                        maxAmplitude = 0
                        sampleCount = 0
                    }
                }

                currentFrame += AVAudioFramePosition(actualFrameCount)
            } catch {
                print("⚠️ Waveform: Error reading audio buffer: \(error.localizedDescription)")
                break
            }
        }

        // Add any remaining sample data
        if sampleCount > 0 && maxAmplitude > 0 {
            waveformData.append(maxAmplitude)
        }

        // Validate we got some data
        guard !waveformData.isEmpty else {
            print("⚠️ Waveform: No waveform data extracted")
            return []
        }

        // Normalize the data
        if let maxValue = waveformData.max(), maxValue > 0 {
            waveformData = waveformData.map { $0 / maxValue }
        }

        print("✅ Waveform: Successfully extracted \(waveformData.count) data points")
        return waveformData
    }
    
    func clearData() {
        // Cancel any ongoing analysis
        currentAnalysisTask?.cancel()
        currentAnalysisTask = nil

        waveformData = []
        hasRealData = false
        isAnalyzing = false
    }
}

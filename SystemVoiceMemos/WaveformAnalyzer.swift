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
    
    func analyzeAudioFile(at url: URL, duration: TimeInterval) async {
        // First, show a placeholder waveform immediately
        await MainActor.run {
            self.waveformData = generatePlaceholderWaveform(duration: duration)
            self.hasRealData = false
            self.isAnalyzing = true
        }
        
        // Then analyze the real audio file in the background
        let realData = await withCheckedContinuation { continuation in
            analysisQueue.async {
                let data = self.extractWaveformData(from: url)
                continuation.resume(returning: data)
            }
        }
        
        // Update with real data when analysis is complete
        await MainActor.run {
            self.waveformData = realData
            self.hasRealData = true
            self.isAnalyzing = false
        }
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
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return []
        }
        
        let frameCount = UInt32(audioFile.length)
        let bufferSize = 4096
        let samplesPerPixel = max(1, Int(frameCount) / 1000) // Aim for ~1000 data points
        
        var waveformData: [Float] = []
        waveformData.reserveCapacity(1000)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: UInt32(bufferSize)) else {
            return []
        }
        
        var currentFrame: AVAudioFramePosition = 0
        var maxAmplitude: Float = 0
        var sampleCount = 0
        
        while currentFrame < frameCount {
            do {
                try audioFile.read(into: buffer, frameCount: UInt32(bufferSize))
                
                guard let channelData = buffer.floatChannelData?[0] else { break }
                let frameCount = Int(buffer.frameLength)
                
                for i in 0..<frameCount {
                    let amplitude = abs(channelData[i])
                    maxAmplitude = max(maxAmplitude, amplitude)
                    sampleCount += 1
                    
                    if sampleCount >= samplesPerPixel {
                        waveformData.append(maxAmplitude)
                        maxAmplitude = 0
                        sampleCount = 0
                    }
                }
                
                currentFrame += AVAudioFramePosition(bufferSize)
            } catch {
                break
            }
        }
        
        // Normalize the data
        if let maxValue = waveformData.max(), maxValue > 0 {
            waveformData = waveformData.map { $0 / maxValue }
        }
        
        return waveformData
    }
    
    func clearData() {
        waveformData = []
        hasRealData = false
        isAnalyzing = false
    }
}

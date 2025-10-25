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
    
    private let analysisQueue = DispatchQueue(label: "waveform.analysis", qos: .userInitiated)
    
    func analyzeAudioFile(at url: URL) async {
        await MainActor.run {
            isAnalyzing = true
        }
        
        let data = await withCheckedContinuation { continuation in
            analysisQueue.async {
                let data = self.extractWaveformData(from: url)
                continuation.resume(returning: data)
            }
        }
        
        await MainActor.run {
            self.waveformData = data
            self.isAnalyzing = false
        }
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
    }
}

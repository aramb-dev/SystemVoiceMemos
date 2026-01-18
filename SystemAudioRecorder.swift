//
//  SystemAudioRecorder.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/9/25.
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import Combine

@MainActor
final class SystemAudioRecorder: NSObject, ObservableObject {

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private let outputQueue = DispatchQueue(label: "SystemVoiceMemos.AudioOutput")

    var isRecording = false
    private var startTime: CMTime = .zero
    private var recordingStartDate: Date?
    private var durationTimer: Timer?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartDate: Date?
    private var pausedCMTimeDuration: CMTime = .zero
    private var lastBufferTime: CMTime = .zero

    // Published properties for UI state
    @Published var currentRecordingDuration: TimeInterval = 0
    @Published var isPaused = false
    @Published var recordingState: RecordingState = .idle
    
    enum RecordingState {
        case idle
        case recording
        case paused
    }

    // Start capture: create a stream that captures AUDIO ONLY (no video)
    func startRecording(to url: URL) async throws {
        guard !isRecording else { return }

        print("🎙️ Starting recording to:", url.path)

        // 1) Choose a capture target. For "system audio", the simplest is the main display.
        let shareable = try await SCShareableContent.current
        print("📺 Available displays:", shareable.displays.count)
        print("📺 Display details:", shareable.displays.map { "ID: \($0.displayID), Width: \($0.width), Height: \($0.height)" })
        
        guard let mainDisplay = shareable.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? shareable.displays.first else {
            print("❌ No display found!")
            throw RecorderError.noDisplay
        }
        print("✅ Selected display ID:", mainDisplay.displayID)

        // 2) Build content filter (we don't capture windows/apps specifically; just the display)
        let filter = SCContentFilter(display: mainDisplay, excludingApplications: [], exceptingWindows: [])

        // 3) Configure stream for AUDIO ONLY
        let config = SCStreamConfiguration()
        config.width = mainDisplay.width
        config.height = mainDisplay.height
        config.capturesAudio = true
        config.sampleRate = 44_100
        config.channelCount = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        // 4) Prepare AVAssetWriter for M4A (AAC)
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw RecorderError.writerCantAddInput }
        writer.add(input)

        self.writer = writer
        self.audioInput = input

        // 5) Create stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream

        print("🔊 Adding audio stream output...")
        // 6) Add audio output
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: outputQueue)
        print("✅ Audio output added")

        // 7) Start
        guard writer.startWriting() else {
            throw RecorderError.writerStartFailed
        }
        startTime = .zero
        pausedCMTimeDuration = .zero
        lastBufferTime = .zero
        writer.startSession(atSourceTime: .zero)
        print("📝 Writer started")

        print("🚀 Starting capture...")
        try await stream.startCapture()
        print("✅ Capture started successfully!")

        isRecording = true
        recordingState = .recording
        isPaused = false

        // Start real-time duration tracking
        recordingStartDate = Date()
        currentRecordingDuration = 0
        pausedDuration = 0
        // Ensure timer starts after state is fully initialized
        startDurationTimer()
    }
    
    func pauseRecording() async {
        guard isRecording, !isPaused else { return }
        
        do {
            try await stream?.stopCapture()
            isPaused = true
            recordingState = .paused
            pauseStartDate = Date()
            durationTimer?.invalidate()
        } catch {
            print("Pause error:", error)
        }
    }
    
    func resumeRecording() async {
        guard isRecording, isPaused else { return }
        
        do {
            if let pauseStart = pauseStartDate {
                let pauseInterval = Date().timeIntervalSince(pauseStart)
                pausedDuration += pauseInterval
                let pauseCMTime = CMTime(seconds: pauseInterval, preferredTimescale: 44100)
                pausedCMTimeDuration = CMTimeAdd(pausedCMTimeDuration, pauseCMTime)
            }
            pauseStartDate = nil
            
            try await stream?.startCapture()
            isPaused = false
            recordingState = .recording
            startDurationTimer()
        } catch {
            print("Resume error:", error)
        }
    }

    private func startDurationTimer() {
        // Update duration every 0.1 seconds for smooth UI updates
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startDate = self.recordingStartDate else { return }
                self.currentRecordingDuration = Date().timeIntervalSince(startDate) - self.pausedDuration
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartDate = nil
        currentRecordingDuration = 0
        pausedDuration = 0
        pauseStartDate = nil
        pausedCMTimeDuration = .zero
        lastBufferTime = .zero
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        recordingState = .idle
        isPaused = false

        // Stop duration tracking
        stopDurationTimer()

        // Stop capture first
        do {
            try await stream?.stopCapture()
        } catch {
            print("stopCapture error:", error)
        }

        // Detach output to avoid stray buffers during teardown
        if let stream = stream {
            do {
                try stream.removeStreamOutput(self, type: .audio)
            } catch {
                print("removeStreamOutput error:", error)
            }
        }

        // Finish writing cleanly
        audioInput?.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer?.finishWriting {
                continuation.resume()
            }
        }

        if let writer, writer.status == .failed {
            print("finishWriting failed:", writer.error ?? RecorderError.writerStartFailed)
        }

        // Release resources
        stream = nil
        audioInput = nil
        writer = nil
    }
}

// MARK: - Errors

enum RecorderError: LocalizedError {
    case noDisplay
    case writerCantAddInput
    case writerStartFailed

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display available to capture."
        case .writerCantAddInput: return "Could not add audio input to writer."
        case .writerStartFailed: return "Failed to start asset writer."
        }
    }
}

// MARK: - Helpers

private extension SCDisplay {
    var cgDisplayID: CGDirectDisplayID { CGDirectDisplayID(displayID) }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as! CGDirectDisplayID
    }
}

// MARK: - SCStreamOutput

extension SystemAudioRecorder: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else {
            return
        }

        Task { @MainActor in
            guard let writer = self.writer,
                  let input = self.audioInput,
                  writer.status == .writing || writer.status == .unknown else {
                return
            }

            if input.isReadyForMoreMediaData {
                let adjustedBuffer = self.adjustSampleBufferTiming(sampleBuffer)
                _ = input.append(adjustedBuffer)
            }
        }
    }
    
    private func adjustSampleBufferTiming(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        let originalTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        lastBufferTime = originalTime
        
        if CMTimeCompare(pausedCMTimeDuration, .zero) == 0 {
            return sampleBuffer
        }
        
        let adjustedTime = CMTimeSubtract(originalTime, pausedCMTimeDuration)
        
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: adjustedTime,
            decodeTimeStamp: .invalid
        )
        
        var adjustedBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            timingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )
        
        if status == noErr, let adjusted = adjustedBuffer {
            return adjusted
        } else {
            print("⚠️ Failed to adjust sample buffer timing, status: \(status)")
            return sampleBuffer
        }
    }
}

// MARK: - SCStreamDelegate

extension SystemAudioRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error:", error)
    }
}

//
//  SystemAudioRecorder.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/9/25.
//
//  Captures system audio using ScreenCaptureKit and writes to M4A files.
//  Supports pause/resume with seamless timestamp adjustment to remove gaps.
//

import Foundation
import AVFoundation
import ScreenCaptureKit

/// Records system audio from the main display to M4A files
///
/// This class:
/// - Uses ScreenCaptureKit to capture system audio (no video)
/// - Writes audio to M4A files with AAC encoding
/// - Supports pause/resume with timestamp adjustment to remove silent gaps
/// - Provides real-time duration tracking for UI updates
/// - Handles sample buffer timing to ensure seamless recordings
@MainActor
final class SystemAudioRecorder: NSObject, ObservableObject {

    // MARK: - Audio Quality

    /// Supported audio quality presets mapped from Settings
    private enum AudioQuality: String {
        case low
        case medium
        case high
        case maximum

        var bitRate: Int {
            switch self {
            case .low:
                return 64_000
            case .medium:
                return 128_000
            case .high:
                return 192_000
            case .maximum:
                return 320_000
            }
        }

        static var current: AudioQuality {
            let stored = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.audioQuality) ?? "high"
            return AudioQuality(rawValue: stored) ?? .high
        }
    }

    // MARK: - Properties
    
    /// The active screen capture stream
    private var stream: SCStream?
    
    /// Asset writer for encoding audio to M4A
    private var writer: AVAssetWriter?
    
    /// Audio input for the asset writer
    private var audioInput: AVAssetWriterInput?
    
    /// Microphone input for the asset writer
    private var micInput: AVAssetWriterInput?
    
    /// Capture session for microphone
    private var captureSession: AVCaptureSession?
    
    /// Queue for processing audio sample buffers
    private let outputQueue = DispatchQueue(label: "SystemVoiceMemos.AudioOutput")

    /// Whether a recording is currently active
    var isRecording = false
    
    /// Start time for the recording session
    private var startTime: CMTime = .zero
    
    /// Date when recording started (for UI duration tracking)
    private var recordingStartDate: Date?
    
    /// Timer for updating UI duration
    private var durationTimer: Timer?
    
    /// Total time spent paused (for UI display)
    private var pausedDuration: TimeInterval = 0
    
    /// Date when pause started
    private var pauseStartDate: Date?
    
    /// Accumulated pause duration in CMTime (for timestamp adjustment)
    private var pausedCMTimeDuration: CMTime = .zero
    
    /// Timestamp of the last processed sample buffer
    private var lastBufferTime: CMTime = .zero

    // MARK: - Published State
    
    /// Current recording duration (excluding paused time)
    @Published var currentRecordingDuration: TimeInterval = 0
    
    /// Whether recording is currently paused
    @Published var isPaused = false
    
    /// Current recording state
    @Published var recordingState: RecordingState = .idle
    
    /// Recording state enumeration
    enum RecordingState {
        case idle
        case recording
        case paused
    }

    // MARK: - Recording Control
    
    /// Starts recording system audio to the specified file
    ///
    /// - Parameter url: The output file URL (should be .m4a)
    /// - Throws: RecorderError if setup fails
    ///
    /// This method:
    /// 1. Selects the main display as the capture source
    /// 2. Configures ScreenCaptureKit for audio-only capture
    /// 3. Sets up AVAssetWriter with AAC encoding
    /// 4. Starts the capture stream
    /// 5. Begins real-time duration tracking
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
        let selectedQuality = AudioQuality.current
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: selectedQuality.bitRate
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw RecorderError.writerCantAddInput }
        writer.add(input)
        self.audioInput = input

        // 4b) Prepare microphone input if needed
        if UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.includeMicrophone) {
            let micSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000
            ]
            let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            micInput.expectsMediaDataInRealTime = true
            if writer.canAdd(micInput) {
                writer.add(micInput)
                self.micInput = micInput
            }

            let session = AVCaptureSession()
            if let device = AVCaptureDevice.default(for: .audio),
               let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if session.canAddInput(deviceInput) {
                    session.addInput(deviceInput)
                }
                let output = AVCaptureAudioDataOutput()
                output.setSampleBufferDelegate(self, queue: outputQueue)
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                self.captureSession = session
            }
        }

        self.writer = writer

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
        
        if let session = captureSession {
            session.startRunning()
        }
        
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
    
    /// Pauses the current recording
    ///
    /// Stops the capture stream and tracks pause duration for timestamp adjustment.
    /// The recording can be resumed with `resumeRecording()`.
    func pauseRecording() async {
        guard isRecording, !isPaused else { return }
        
        do {
            try await stream?.stopCapture()
            captureSession?.stopRunning()
            isPaused = true
            recordingState = .paused
            pauseStartDate = Date()
            durationTimer?.invalidate()
        } catch {
            print("Pause error:", error)
        }
    }
    
    /// Resumes a paused recording
    ///
    /// Restarts the capture stream and accumulates pause duration.
    /// Sample buffer timestamps will be adjusted to remove the pause gap.
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
            captureSession?.startRunning()
            isPaused = false
            recordingState = .recording
            startDurationTimer()
        } catch {
            print("Resume error:", error)
        }
    }

    // MARK: - Duration Tracking
    
    /// Starts the timer for updating UI duration
    ///
    /// Updates every 0.1 seconds to provide smooth UI updates.
    /// Duration excludes time spent paused.
    private func startDurationTimer() {
        // Update duration every 0.1 seconds for smooth UI updates
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startDate = self.recordingStartDate else { return }
                self.currentRecordingDuration = Date().timeIntervalSince(startDate) - self.pausedDuration
            }
        }
    }

    /// Stops the duration timer and resets tracking state
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

    /// Stops the recording and finalizes the output file
    ///
    /// This method:
    /// 1. Stops the capture stream
    /// 2. Removes stream outputs
    /// 3. Finalizes the asset writer
    /// 4. Cleans up resources
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
            captureSession?.stopRunning()
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
        micInput?.markAsFinished()
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
        micInput = nil
        captureSession = nil
        writer = nil
    }
}

// MARK: - Error Types

/// Errors that can occur during recording
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

// MARK: - Extensions

/// Helper extension for SCDisplay
private extension SCDisplay {
    var cgDisplayID: CGDirectDisplayID { CGDirectDisplayID(displayID) }
}

/// Helper extension for NSScreen
private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as! CGDirectDisplayID
    }
}

// MARK: - Stream Output Handling

/// Handles audio sample buffers from the capture stream
extension SystemAudioRecorder: SCStreamOutput, AVCaptureAudioDataOutputSampleBufferDelegate {
    /// Receives audio sample buffers from the capture stream
    ///
    /// - Parameters:
    ///   - stream: The capture stream
    ///   - sampleBuffer: The audio sample buffer
    ///   - outputType: The type of output (audio or video)
    ///
    /// This method adjusts sample buffer timestamps to remove pause gaps
    /// before appending to the asset writer.
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else {
            return
        }

        processSampleBuffer(sampleBuffer, forMic: false)
    }

    /// Receives audio sample buffers from the microphone
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        processSampleBuffer(sampleBuffer, forMic: true)
    }

    /// Processes a sample buffer and appends it to the appropriate writer input
    nonisolated private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, forMic: Bool) {
        Task { @MainActor in
            guard let writer = self.writer,
                  writer.status == .writing || writer.status == .unknown else {
                return
            }

            let input = forMic ? self.micInput : self.audioInput
            
            if let input = input, input.isReadyForMoreMediaData {
                let adjustedBuffer = self.adjustSampleBufferTiming(sampleBuffer)
                _ = input.append(adjustedBuffer)
            }
        }
    }
    
    /// Adjusts sample buffer timestamps to remove pause gaps
    ///
    /// - Parameter sampleBuffer: The original sample buffer
    /// - Returns: A new sample buffer with adjusted timing, or the original if adjustment fails
    ///
    /// This method subtracts the accumulated pause duration from the buffer's
    /// presentation timestamp to create seamless recordings without silent gaps.
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
            sampleTimingArray: &timingInfo,
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

// MARK: - Stream Delegate

/// Handles stream lifecycle events
extension SystemAudioRecorder: SCStreamDelegate {
    /// Called when the stream stops with an error
    ///
    /// - Parameters:
    ///   - stream: The capture stream
    ///   - error: The error that caused the stream to stop
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error:", error)
    }
}

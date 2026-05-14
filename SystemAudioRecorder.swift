//
//  SystemAudioRecorder.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/9/25.
//
//  Captures system audio using ScreenCaptureKit and writes to M4A files.
//  Supports pause/resume with seamless timestamp adjustment to remove gaps.
//

import AVFoundation
import Foundation
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

    /// Core Audio tap backend for system audio without ScreenCaptureKit.
    @available(macOS 14.2, *)
    private var coreAudioTapRecorder: CoreAudioTapRecorder {
        if let recorder = _coreAudioTapRecorder as? CoreAudioTapRecorder {
            return recorder
        }
        let recorder = CoreAudioTapRecorder()
        _coreAudioTapRecorder = recorder
        return recorder
    }

    private var _coreAudioTapRecorder: Any?

    /// The source used by the active recording.
    private var activeRecordingSource: RecordingSource?

    /// Queue for processing audio sample buffers
    private let outputQueue = DispatchQueue(label: "SystemVoiceMemos.AudioOutput")

    /// Serial queue used to start/stop AVCaptureSession off the main thread.
    /// startRunning() and stopRunning() are synchronous and can block for
    /// hundreds of milliseconds, so they must never run on the main actor.
    private let sessionControlQueue = DispatchQueue(
        label: "SystemVoiceMemos.SessionControl",
        qos: .userInitiated
    )

    /// Tiny placeholder dimensions keep any accidental screen stream cheap.
    /// System audio still needs a display-anchored ScreenCaptureKit stream,
    /// but this recorder never subscribes to or writes screen frames.
    private let audioOnlyStreamDimension = 2

    /// Whether a recording is currently active
    var isRecording = false

    /// Start time for the recording session
    private var startTime: CMTime = .invalid

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

    /// Whether the microphone track is currently muted (recording continues; mic samples are silenced)
    @Published var isMicMuted = false

    /// Whether the active recording includes a microphone track (used to show/hide mute button)
    @Published var hasMicTrack = false

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
    /// Starts recording system audio to the specified file URL using the currently selected recording source.
    /// 
    /// Depending on `RecordingSource.current` this will start one of:
    /// - the core-audio-tap backend,
    /// - a microphone-only capture, or
    /// - a display-anchored audio capture that writes AAC audio to an `.m4a` file.
    /// The function configures and starts the necessary capture session(s), AVAssetWriter inputs, and stream outputs, and updates recorder state and timing for pause/resume tracking.
    /// - Parameter url: Destination file URL for the recorded `.m4a`.
    /// - Throws: `RecorderError.noDisplay` when no suitable display can be selected for display-anchored audio; `RecorderError.noMicrophone` when a required microphone is unavailable; `RecorderError.permissionDenied` when microphone permission is denied; `RecorderError.writerCantAddInput` when an AVAssetWriter input cannot be added; `RecorderError.writerStartFailed` when the writer fails to start; or other errors propagated from underlying capture/stream components.
    func startRecording(to url: URL) async throws {
        guard !isRecording else { return }

        print("🎙️ Starting recording to:", url.path)

        let source = RecordingSource.current
        activeRecordingSource = source

        switch source {
        case .coreAudioTap:
            try await startCoreAudioTapRecording(to: url)
            markRecordingStarted()
            return
        case .microphoneOnly:
            try startMicrophoneOnlyRecording(to: url)
            markRecordingStarted()
            return
        case .legacyScreenCapture:
            break
        }

        // 1) Choose a display only as the system-audio source anchor.
        // No screen output is registered, so pixels are not delivered or recorded.
        let shareable = try await SCShareableContent.current
        print("📺 Available displays:", shareable.displays.count)
        print("📺 Display details:", shareable.displays.map { "ID: \($0.displayID), Width: \($0.width), Height: \($0.height)" })

        guard let mainDisplay = shareable.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? shareable.displays.first else {
            print("❌ No display found!")
            throw RecorderError.noDisplay
        }
        print("✅ Selected display ID:", mainDisplay.displayID)

        // 2) Build a display filter for audio routing, not video capture.
        let filter = SCContentFilter(display: mainDisplay, excludingApplications: [], exceptingWindows: [])

        // 3) Configure stream for audio only. Screen-related values are inert
        // because we only add the .audio stream output below.
        let config = makeAudioOnlyStreamConfiguration()

        // 4) Prepare AVAssetWriter for M4A (AAC)
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let selectedQuality = AudioQuality.current
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: selectedQuality.bitRate,
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw RecorderError.writerCantAddInput }
        writer.add(input)
        audioInput = input

        // 4b) Prepare microphone input if needed
        if UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.includeMicrophone) {
            let micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            guard micAuthStatus == .authorized else {
                throw micAuthStatus == .notDetermined ? RecorderError.noMicrophone : RecorderError.permissionDenied
            }

            let micSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64000,
            ]
            let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            micInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(micInput) else { throw RecorderError.writerCantAddInput }
            writer.add(micInput)
            self.micInput = micInput

            captureSession = try makeMicrophoneCaptureSession()
        }

        self.writer = writer

        do {
            // 5) Create stream
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            self.stream = stream

            print("🔊 Adding audio stream output...")
            // 6) Add only audio output. Do not add .screen output.
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: outputQueue)
            print("✅ Audio output added")

            // 7) Start
            guard writer.startWriting() else {
                throw RecorderError.writerStartFailed
            }
            startTime = .invalid
            pausedCMTimeDuration = .zero
            lastBufferTime = .zero
            writer.startSession(atSourceTime: .zero)
            print("📝 Writer started")

            print("🚀 Starting capture...")
            try await stream.startCapture()

            startCaptureSession(captureSession)

            print("✅ Capture started successfully!")
            markRecordingStarted()
        } catch {
            stopCaptureSession(captureSession)
            if writer.status == .writing { writer.cancelWriting() }
            self.stream = nil
            self.writer = nil
            self.audioInput = nil
            self.micInput = nil
            self.captureSession = nil
            self.activeRecordingSource = nil
            throw error
        }
    }

    /// Starts a Core Audio Tap recording and writes captured audio to the provided file URL.
    /// - Parameter url: Destination file URL for the recorded audio (.m4a).
    /// - Throws: `CoreAudioTapRecorderError.unavailable` if Core Audio Tap is not supported on the running macOS version. Rethrows any error produced while configuring or starting the Core Audio Tap recorder or while creating the optional microphone capture session.
    /// - Important: If the user preference to include the microphone is enabled, a microphone `AVCaptureSession` will be created and started alongside the Core Audio Tap recording.
    private func startCoreAudioTapRecording(to url: URL) async throws {
        guard #available(macOS 14.2, *) else {
            throw CoreAudioTapRecorderError.unavailable
        }

        let includeMicrophone = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.includeMicrophone)
        let session = includeMicrophone ? try makeMicrophoneCaptureSession() : nil

        do {
            try coreAudioTapRecorder.startRecording(
                to: url,
                bitRate: AudioQuality.current.bitRate,
                includeMicrophone: includeMicrophone
            )
            captureSession = session
            startCaptureSession(captureSession)
        } catch {
            stopCaptureSession(session)
            captureSession = nil
            await coreAudioTapRecorder.stopRecording()
            throw error
        }
        print("✅ Core Audio tap capture started successfully!")
    }

    /// Configure an AAC microphone-only AVAssetWriter, start an AVCaptureSession for the selected microphone, and begin writing audio to the provided file URL.
    /// - Parameter to: Destination file URL for the resulting `.m4a` recording.
    /// - Throws: `RecorderError.writerCantAddInput` if the writer cannot accept the audio input; `RecorderError.noMicrophone` if microphone permission has not been determined; `RecorderError.permissionDenied` if microphone access is denied; `RecorderError.writerStartFailed` if the writer fails to start. Errors thrown by `AVAssetWriter` initializers or `makeMicrophoneCaptureSession()` are propagated.
    private func startMicrophoneOnlyRecording(to url: URL) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let micSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: AudioQuality.current.bitRate,
        ]

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw RecorderError.writerCantAddInput }
        writer.add(input)

        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard authStatus == .authorized else {
            throw authStatus == .notDetermined ? RecorderError.noMicrophone : RecorderError.permissionDenied
        }
        let session = try makeMicrophoneCaptureSession()

        guard writer.startWriting() else {
            throw RecorderError.writerStartFailed
        }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        audioInput = input
        captureSession = session
        startCaptureSession(session)
        print("✅ Microphone-only capture started successfully!")
    }

    /// Creates and returns an AVCaptureSession configured to capture microphone audio.
    /// 
    /// The session selects a microphone by the stored `selectedMicrophoneUID` user default when present, falling back to the system default microphone if not. The returned session includes an audio input for the chosen device and an AVCaptureAudioDataOutput whose sample-buffer delegate is set on the recorder's audio queue.
    /// - Returns: An `AVCaptureSession` configured for microphone capture and ready to be started.
    /// - Throws:
    ///   - `RecorderError.noMicrophone` if no suitable audio device is available or the device cannot be added to the session.
    ///   - `RecorderError.deviceUnavailable(_)` if creating an `AVCaptureDeviceInput` for the chosen device fails (includes the underlying error message).
    ///   - `RecorderError.captureSessionCantAddOutput` if the session cannot accept the audio output.
    private func makeMicrophoneCaptureSession() throws -> AVCaptureSession {
        let storedUID = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.selectedMicrophoneUID) ?? ""
        let micDevice = storedUID.isEmpty
            ? AVCaptureDevice.default(for: .audio)
            : AVCaptureDevice(uniqueID: storedUID) ?? AVCaptureDevice.default(for: .audio)

        guard let device = micDevice else {
            throw RecorderError.noMicrophone
        }

        let deviceInput: AVCaptureDeviceInput
        do {
            deviceInput = try AVCaptureDeviceInput(device: device)
        } catch {
            throw RecorderError.deviceUnavailable(error.localizedDescription)
        }

        let session = AVCaptureSession()
        guard session.canAddInput(deviceInput) else {
            throw RecorderError.noMicrophone
        }
        session.addInput(deviceInput)

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(output) else {
            throw RecorderError.captureSessionCantAddOutput
        }
        session.addOutput(output)
        return session
    }

    /// Marks the recorder as started and initializes recording state and timing.
    /// 
    /// Resets pause-related trackers, sample-buffer timing anchors, and UI duration counters, sets `isRecording`/`recordingState`/`isPaused` appropriately, and starts the duration timer.
    private func markRecordingStarted() {
        isRecording = true
        recordingState = .recording
        isPaused = false
        isMicMuted = false
        recordingStartDate = Date()
        currentRecordingDuration = 0
        pausedDuration = 0
        pauseStartDate = nil
        pausedCMTimeDuration = .zero
        startTime = .invalid
        lastBufferTime = .zero
        // Reflect whether this recording will contain a mic track.
        let source = activeRecordingSource ?? RecordingSource.current
        hasMicTrack = source == .microphoneOnly
            || (source != .microphoneOnly && UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.includeMicrophone))
        startDurationTimer()
    }

    /// Builds the lowest-overhead ScreenCaptureKit configuration this recorder needs.
    private func makeAudioOnlyStreamConfiguration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = audioOnlyStreamDimension
        config.height = audioOnlyStreamDimension
        config.capturesAudio = true
        config.sampleRate = 44100
        config.channelCount = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 1
        config.showsCursor = false
        return config
    }

    /// Pauses the current recording
    ///
    /// Stops the capture stream and tracks pause duration for timestamp adjustment.
    /// Pauses an active recording and updates internal state and timers.
    /// 
    /// If no recording is active or recording is already paused, the call returns immediately.
    /// For the core-audio-tap source, the recorder's pause is invoked and the microphone capture session is stopped.
    /// For other sources, the stream capture is stopped and the microphone capture session is stopped.
    /// In all cases the recorder's paused state, recordingState, pause start timestamp are set and the duration timer is invalidated.
    func pauseRecording() async {
        guard isRecording, !isPaused else { return }

        if activeRecordingSource == .coreAudioTap {
            if #available(macOS 14.2, *) {
                coreAudioTapRecorder.pauseRecording()
            }
            stopCaptureSession(captureSession)
            isPaused = true
            recordingState = .paused
            pauseStartDate = Date()
            durationTimer?.invalidate()
            return
        }

        do {
            try await stream?.stopCapture()
            stopCaptureSession(captureSession)
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
    /// Resumes an in-progress, paused recording and updates recording timing and state.
    /// 
    /// If a pause was active, accumulates the wall-clock pause time into `pausedDuration` and converts it
    /// to a `CMTime` added to `pausedCMTimeDuration` for sample timestamp adjustment. Then resumes capture
    /// according to the current `activeRecordingSource`: for the core-audio-tap path the tap is resumed
    /// and the microphone `AVCaptureSession` is started; for other paths the `SCStream` capture is restarted
    /// and the microphone session is started. Finally clears `pauseStartDate`, sets `isPaused` to `false`,
    /// updates `recordingState` to `.recording`, and restarts the duration timer.
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

            if activeRecordingSource == .coreAudioTap {
                if #available(macOS 14.2, *) {
                    try coreAudioTapRecorder.resumeRecording()
                }
                startCaptureSession(captureSession)
                isPaused = false
                recordingState = .recording
                startDurationTimer()
                return
            }

            try await stream?.startCapture()
            startCaptureSession(captureSession)
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
    /// Stops an active recording, finalizes any in-progress asset writing, and releases capture resources.
    /// 
    /// When called while recording, this updates recorder state to idle and stops duration tracking. For the core-audio-tap recording path it stops the tap and the microphone capture session; for the AVAssetWriter/SCStream path it stops stream capture, detaches the stream output, marks writer inputs finished, waits for the writer to finish, and then clears all capture/writer-related properties. Any finish or capture errors are logged to the console.
    func stopRecording() async {
        guard isRecording else { return }
        let source = activeRecordingSource
        isRecording = false
        recordingState = .idle
        isPaused = false
        isMicMuted = false
        hasMicTrack = false

        // Stop duration tracking
        stopDurationTimer()

        if source == .coreAudioTap {
            stopCaptureSession(captureSession)
            if #available(macOS 14.2, *) {
                await coreAudioTapRecorder.stopRecording()
                if let writeError = coreAudioTapRecorder.lastWriteError {
                    print("CoreAudioTap write error during recording:", writeError)
                }
            }
            captureSession = nil
            activeRecordingSource = nil
            return
        }

        // Stop capture first
        do {
            try await stream?.stopCapture()
            stopCaptureSession(captureSession)
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
        activeRecordingSource = nil
    }
}

// MARK: - Session Control Helpers

extension SystemAudioRecorder {
    /// Starts `session.startRunning()` on `sessionControlQueue` so the blocking
    /// call never runs on the main actor / main thread.
    private func startCaptureSession(_ session: AVCaptureSession?) {
        guard let s = session else { return }
        sessionControlQueue.async { s.startRunning() }
    }

    /// Stops `session.stopRunning()` on `sessionControlQueue` so the blocking
    /// call never runs on the main actor / main thread.
    private func stopCaptureSession(_ session: AVCaptureSession?) {
        guard let s = session else { return }
        sessionControlQueue.async { s.stopRunning() }
    }
}

// MARK: - Error Types

/// Errors that can occur during recording
enum RecorderError: LocalizedError {
    case noDisplay
    case noMicrophone
    case permissionDenied
    case deviceUnavailable(String)
    case writerCantAddInput
    case writerStartFailed
    case captureSessionCantAddOutput

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display available to capture."
        case .noMicrophone: return "No microphone available to capture."
        case .permissionDenied: return "Microphone access is denied. Enable it in System Settings > Privacy & Security."
        case .deviceUnavailable(let reason): return "Microphone unavailable: \(reason)"
        case .writerCantAddInput: return "Could not add audio input to writer."
        case .writerStartFailed: return "Failed to start asset writer."
        case .captureSessionCantAddOutput: return "Could not add output to capture session."
        }
    }
}

// MARK: - Extensions

/// Helper extension for SCDisplay
private extension SCDisplay {
    var cgDisplayID: CGDirectDisplayID {
        CGDirectDisplayID(displayID)
    }
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
    nonisolated func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else {
            // Defensive only: this stream never registers screen output.
            return
        }

        processSampleBuffer(sampleBuffer, forMic: false)
    }

    /// Handles incoming microphone audio sample buffers and forwards them to the active recording backend.
    /// 
    /// When the recorder's active source is the Core Audio Tap, forwards the buffer to the Core Audio Tap recorder. Otherwise, if an `AVAssetWriter` is active and in a writable state, adjusts the sample buffer's timing and appends it to the appropriate writer input (uses the primary audio track for microphone-only recordings, and the secondary mic track when recording system audio alongside the microphone). This work is performed on the main actor.
    /// - Parameter sampleBuffer: A CMSampleBuffer containing the captured microphone audio frames.
    nonisolated func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        Task { @MainActor in
            // When mic is muted, discard the buffer — recording continues without mic audio.
            guard !self.isMicMuted else { return }

            if self.activeRecordingSource == .coreAudioTap {
                if #available(macOS 14.2, *) {
                    self.coreAudioTapRecorder.appendMicrophoneSampleBuffer(sampleBuffer)
                }
                return
            }

            guard let writer = self.writer,
                  writer.status == .writing || writer.status == .unknown
            else { return }
            // Mic-only: append to audioInput (single primary track).
            // Legacy+mic: append to micInput (secondary track alongside system audio).
            let isMicOnly = self.activeRecordingSource == .microphoneOnly
            let input = isMicOnly ? self.audioInput : self.micInput
            if let input, input.isReadyForMoreMediaData {
                let adjusted = self.adjustSampleBufferTiming(sampleBuffer)
                _ = input.append(adjusted)
            }
        }
    }

    /// Processes a sample buffer and appends it to the appropriate writer input
    private nonisolated func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, forMic: Bool) {
        Task { @MainActor in
            guard let writer = self.writer,
                  writer.status == .writing || writer.status == .unknown
            else {
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
        guard originalTime.isValid else { return sampleBuffer }

        if !startTime.isValid {
            startTime = originalTime
        }

        lastBufferTime = originalTime

        let elapsedTime = CMTimeSubtract(originalTime, startTime)
        let adjustedTime = CMTimeSubtract(elapsedTime, pausedCMTimeDuration)

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
    nonisolated func stream(_: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error:", error)
    }
}

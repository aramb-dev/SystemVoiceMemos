//
//  CoreAudioTapRecorder.swift
//  SystemVoiceMemos
//

import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

@available(macOS 14.2, *)
final class CoreAudioTapRecorder: @unchecked Sendable {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var writer: AVAssetWriter?
    private var systemInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var systemFormatDescription: CMAudioFormatDescription?
    private var clientFormat = AudioStreamBasicDescription()
    private var systemFramePosition: Int64 = 0
    private var micStartTime: CMTime = .invalid
    private var micPausedDuration: CMTime = .zero

    // Lock protecting _isPaused and _lastWriteError — both are read from the
    // Core Audio IO callback queue and written from the caller (main actor).
    private let stateLock = NSLock()
    private var _isPaused = false
    private var _lastWriteError: (any Error)?
    private var pauseStartedAt: Date?

    // Stored so cleanup() can drain in-flight callbacks before finalizing writer state.
    private let callbackQueue = DispatchQueue(label: "SystemVoiceMemos.CoreAudioTap.IO")
    private let writerQueue = DispatchQueue(label: "SystemVoiceMemos.CoreAudioTap.Writer")

    var isPaused: Bool { stateLock.withLock { _isPaused } }

    /// Non-nil after `stopRecording()` if any async write failed during capture.
    var lastWriteError: (any Error)? {
        stateLock.withLock { _lastWriteError }
    }

    /// Begins capturing system audio and writes it to an M4A file at the given URL, optionally adding a microphone track.
    /// 
    /// Sets up a Core Audio process tap, reads the tap format, creates a `CMAudioFormatDescription` and an `AVAssetWriter` (with a system audio input and an optional microphone input), creates a private aggregate device that hosts the tap, installs the IO proc that converts incoming buffers to `CMSampleBuffer`, and starts the aggregate device.
    /// - Parameters:
    ///   - url: Destination file URL for the resulting M4A file.
    ///   - bitRate: Target audio bit rate for the system audio track (in bits per second).
    ///   - includeMicrophone: If `true`, also creates and enables a microphone AAC track in the writer.
    /// - Throws: An error if any part of the setup fails — for example, Core Audio `OSStatus` failures (wrapped as `CoreAudioTapRecorderError.osStatus(...)`), writer/setup failures (`CoreAudioTapRecorderError.setupFailed(...)`), or other errors propagated from helper routines.
    func startRecording(to url: URL, bitRate: Int, includeMicrophone: Bool = false) throws {
        stateLock.withLock {
            _lastWriteError = nil
            _isPaused = false
            pauseStartedAt = nil
        }
        cleanup(cancelWriting: true)

        do {
            let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
            tapDescription.name = "System Voice Memos System Audio"
            tapDescription.uuid = UUID()
            tapDescription.isPrivate = true
            tapDescription.muteBehavior = .unmuted

            try checkStatus(
                AudioHardwareCreateProcessTap(tapDescription, &tapID),
                context: "create Core Audio process tap"
            )

            clientFormat = try readTapFormat(tapID)
            systemFormatDescription = try makeFormatDescription(from: clientFormat)
            try createWriter(at: url, bitRate: bitRate, includeMicrophone: includeMicrophone)
            try createAggregateDevice(tapUUID: tapDescription.uuid)
            try createIOProc()
            try checkStatus(AudioDeviceStart(aggregateDeviceID, ioProcID), context: "start Core Audio tap device")
        } catch {
            cleanup(cancelWriting: true)
            throw error
        }
    }

    /// Pauses the recorder and records when the pause began.
    /// - Discussion: If an aggregate device is active, hardware capture is stopped. The paused flag and `pauseStartedAt` timestamp are set atomically.
    func pauseRecording() {
        guard !isPaused else { return }
        if aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioDeviceStop(aggregateDeviceID, ioProcID)
        }
        stateLock.withLock {
            _isPaused = true
            pauseStartedAt = Date()
        }
    }

    /// Resumes audio capture, compensates microphone timestamps for the paused interval, and restarts the Core Audio tap device.
    /// - Note: If recording is not paused, this method returns immediately.
    /// - Throws: `CoreAudioTapRecorderError.osStatus` if starting the Core Audio tap device fails.
    func resumeRecording() throws {
        guard isPaused else { return }
        let pauseInterval = stateLock.withLock { () -> TimeInterval in
            guard let pauseStartedAt else { return 0 }
            return Date().timeIntervalSince(pauseStartedAt)
        }
        if pauseInterval > 0 {
            writerQueue.sync {
                let pauseTime = CMTime(seconds: pauseInterval, preferredTimescale: 44100)
                micPausedDuration = CMTimeAdd(micPausedDuration, pauseTime)
            }
        }
        try checkStatus(AudioDeviceStart(aggregateDeviceID, ioProcID), context: "resume Core Audio tap device")
        stateLock.withLock {
            _isPaused = false
            pauseStartedAt = nil
        }
    }

    /// Stops hardware capture, drains any in-flight Core Audio callbacks, finalizes pending writer work, and resets internal recording state.
    /// 
    /// This will stop the underlying audio hardware and IO callback, ensure any in-progress sample writes are finished, clear writer-related resources, and clear the paused flag and pause timestamp.
    func stopRecording() async {
        stopHardware()
        callbackQueue.sync {}
        await finishWriter()
        resetWriterState()
        stateLock.withLock {
            _isPaused = false
            pauseStartedAt = nil
        }
    }

    /// Appends a microphone audio sample buffer to the recorder's microphone input after adjusting its timestamps for paused intervals.
    /// - Parameter sampleBuffer: A `CMSampleBuffer` containing microphone audio; its presentation timestamps will be adjusted to account for accumulated paused duration before being appended. If the recorder is paused, the writer is not ready, or appending fails, the buffer is discarded. On the first append failure the recorder records the write error.
    func appendMicrophoneSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard !isPaused else { return }
        writerQueue.async { [weak self] in
            guard let self,
                  let micInput = self.micInput,
                  let writer = self.writer,
                  writer.status == .writing,
                  micInput.isReadyForMoreMediaData
            else { return }

            let adjusted = self.adjustMicrophoneTiming(sampleBuffer)
            guard micInput.append(adjusted) else {
                self.recordWriteError(writer.error ?? CoreAudioTapRecorderError.setupFailed("Could not append microphone audio."))
                return
            }
        }
    }

    /// Creates a private aggregate audio device that exposes the given process tap and stores its device ID.
    /// - Parameter tapUUID: The UUID of the process tap to include in the aggregate device's tap list.
    /// - Throws: `CoreAudioTapRecorderError.osStatus` if creating the aggregate device fails.
    private func createAggregateDevice(tapUUID: UUID) throws {
        let tapDescription: [String: Any] = [
            kAudioSubTapUIDKey: tapUUID.uuidString,
            kAudioSubTapDriftCompensationKey: 1,
            kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationLowQuality,
        ]

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "System Voice Memos Tap",
            kAudioAggregateDeviceUIDKey: "SystemVoiceMemos.Tap.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [tapDescription],
        ]

        try checkStatus(
            AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregateDeviceID),
            context: "create private tap aggregate device"
        )
    }

    /// Register the Core Audio IO callback that converts process-tap input into `CMSampleBuffer` objects and appends them to the recorder's system `AVAssetWriterInput`.
    /// 
    /// The installed callback timestamps incoming frames using `systemFramePosition`, increments that position, and records the first write or buffer-creation error observed during capture.
    /// - Throws: `CoreAudioTapRecorderError.setupFailed` if required writer inputs or format description are missing; `CoreAudioTapRecorderError.osStatus` if creating the IO proc with Core Audio fails.
    private func createIOProc() throws {
        guard systemInput != nil, systemFormatDescription != nil else {
            throw CoreAudioTapRecorderError.setupFailed("Core Audio tap asset writer is missing.")
        }

        let block: AudioDeviceIOBlock = { [weak self] _, inputData, _, _, _ in
            guard let self,
                  !self.stateLock.withLock({ self._isPaused })
            else {
                return
            }

            let frameCount = self.frameCount(from: inputData)
            guard frameCount > 0 else { return }

            let presentationFrame = self.systemFramePosition
            self.systemFramePosition += Int64(frameCount)

            do {
                let sampleBuffer = try self.makeSystemSampleBuffer(
                    from: inputData,
                    frameCount: frameCount,
                    presentationFrame: presentationFrame
                )
                self.appendSystemSampleBuffer(sampleBuffer)
            } catch {
                self.recordWriteError(error)
            }
        }

        try checkStatus(
            AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateDeviceID, callbackQueue, block),
            context: "create Core Audio tap IO callback"
        )
    }

    /// Compute the number of audio frames represented by the first buffer in the provided `AudioBufferList`.
    /// - Parameter audioBufferList: Pointer to an `AudioBufferList`; the first buffer's `mDataByteSize` is used for the calculation.
    /// - Returns: The frame count computed as `firstBuffer.mDataByteSize / clientFormat.mBytesPerFrame`, or `0` if `clientFormat.mBytesPerFrame` is not positive or the buffer list contains no buffers.
    private func frameCount(from audioBufferList: UnsafePointer<AudioBufferList>) -> UInt32 {
        guard clientFormat.mBytesPerFrame > 0 else { return 0 }
        guard audioBufferList.pointee.mNumberBuffers > 0 else { return 0 }
        let firstBuffer = audioBufferList.pointee.mBuffers
        return firstBuffer.mDataByteSize / clientFormat.mBytesPerFrame
    }

    /// Configure and start an `AVAssetWriter` to write system audio (and optionally microphone audio) to an M4A file.
    /// - Parameters:
    ///   - url: Destination file URL for the resulting `.m4a`.
    ///   - bitRate: Target encoder bit rate (in bits per second) for the system audio track.
    ///   - includeMicrophone: If `true`, also add a mono microphone AAC track at 44.1 kHz and 64 kbps.
    /// - Throws: `CoreAudioTapRecorderError.setupFailed` on configuration failures or the writer's error if `startWriting()` fails.
    /// - Postconditions: On success the recorder's `writer`, `systemInput`, and optional `micInput` are set and timing state (`systemFramePosition`, `micStartTime`, `micPausedDuration`) is reset.
    private func createWriter(at url: URL, bitRate: Int, includeMicrophone: Bool) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let sampleRate = clientFormat.mSampleRate > 0 ? clientFormat.mSampleRate : 44100
        let channelCount = Int(max(clientFormat.mChannelsPerFrame, 1))
        let systemSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVEncoderBitRateKey: bitRate,
        ]
        let systemInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: systemSettings,
            sourceFormatHint: systemFormatDescription
        )
        systemInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(systemInput) else { throw CoreAudioTapRecorderError.setupFailed("Could not add system audio track.") }
        writer.add(systemInput)

        var micInput: AVAssetWriterInput?
        if includeMicrophone {
            let micSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64000,
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw CoreAudioTapRecorderError.setupFailed("Could not add microphone audio track.") }
            writer.add(input)
            micInput = input
        }

        // Perform startWriting, startSession, and all property assignments on
        // writerQueue so that every subsequent writerQueue.async read sees a
        // fully-initialised state without needing extra synchronisation.
        try writerQueue.sync {
            guard writer.startWriting() else {
                throw writer.error ?? CoreAudioTapRecorderError.setupFailed("Could not start Core Audio asset writer.")
            }
            writer.startSession(atSourceTime: .zero)

            self.writer = writer
            self.systemInput = systemInput
            self.micInput = micInput
            self.systemFramePosition = 0
            self.micStartTime = .invalid
            self.micPausedDuration = .zero
        }
    }

    /// Appends a system audio sample buffer to the asset writer's system input.
    /// - Description: If the writer is not in a writable state or the system input is not ready for more media data, the buffer is ignored. If appending fails, the first write error is recorded for later inspection.
    /// - Parameters:
    ///   - sampleBuffer: A `CMSampleBuffer` containing system audio and its presentation timing.
    private func appendSystemSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self,
                  let systemInput = self.systemInput,
                  let writer = self.writer,
                  writer.status == .writing,
                  systemInput.isReadyForMoreMediaData
            else { return }

            guard systemInput.append(sampleBuffer) else {
                self.recordWriteError(writer.error ?? CoreAudioTapRecorderError.setupFailed("Could not append system audio."))
                return
            }
        }
    }

    /// Create a `CMSampleBuffer` that wraps the provided Core Audio `AudioBufferList`
    /// and assigns timing based on a presentation frame index using the tap's sample rate.
    /// - Parameters:
    ///   - audioBufferList: Pointer to the audio buffers produced by the Core Audio tap.
    ///   - frameCount: Number of audio frames contained in `audioBufferList`.
    ///   - presentationFrame: Monotonic presentation frame index used to compute the buffer's presentation timestamp (measured in tap sample frames).
    /// - Returns: A `CMSampleBuffer` containing `frameCount` frames and timing derived from `presentationFrame`.
    /// - Throws: `CoreAudioTapRecorderError.setupFailed` if the recorder's format description is missing or the sample buffer fails to be created; `CoreAudioTapRecorderError.osStatus` when underlying Core Media/Core Audio calls return a non-`noErr` status.
    private func makeSystemSampleBuffer(
        from audioBufferList: UnsafePointer<AudioBufferList>,
        frameCount: UInt32,
        presentationFrame: Int64
    ) throws -> CMSampleBuffer {
        guard let systemFormatDescription else {
            throw CoreAudioTapRecorderError.setupFailed("Core Audio tap format is missing.")
        }

        let sampleRate = CMTimeScale(clientFormat.mSampleRate > 0 ? clientFormat.mSampleRate : 44100)
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: CMTimeValue(frameCount), timescale: sampleRate),
            presentationTimeStamp: CMTime(value: CMTimeValue(presentationFrame), timescale: sampleRate),
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: systemFormatDescription,
            sampleCount: CMItemCount(frameCount),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        try checkStatus(createStatus, context: "create system audio sample buffer")

        guard let sampleBuffer else {
            throw CoreAudioTapRecorderError.setupFailed("System audio sample buffer was not created.")
        }

        let dataStatus = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: audioBufferList
        )
        try checkStatus(dataStatus, context: "copy system audio buffer data")

        return sampleBuffer
    }

    /// Adjusts a microphone sample buffer's presentation timestamp to account for the recorder's start time and accumulated paused duration.
    /// 
    /// If this is the first valid microphone buffer, `micStartTime` is set to its original timestamp. The returned buffer's presentation timestamp
    /// is (originalTimestamp - micStartTime - micPausedDuration). If the original timestamp is invalid, or creating a new buffer fails,
    /// the original `sampleBuffer` is returned; a failure to create a new buffer is also recorded via `recordWriteError`.
    /// - Returns: A `CMSampleBuffer` with its presentation timestamp adjusted for recorder start and pauses, or the original buffer if adjustment failed.
    private func adjustMicrophoneTiming(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        let originalTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard originalTime.isValid else { return sampleBuffer }

        if !micStartTime.isValid {
            micStartTime = originalTime
        }

        let elapsedTime = CMTimeSubtract(originalTime, micStartTime)
        let adjustedTime = CMTimeSubtract(elapsedTime, micPausedDuration)
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

        if status == noErr, let adjustedBuffer {
            return adjustedBuffer
        }
        recordWriteError(CoreAudioTapRecorderError.osStatus(status, context: "adjust microphone timing"))
        return sampleBuffer
    }

    /// Create a `CMAudioFormatDescription` from an `AudioStreamBasicDescription`.
    /// - Parameter format: An `AudioStreamBasicDescription` describing the audio stream format to convert.
    /// - Returns: A `CMAudioFormatDescription` representing the provided audio stream format.
    /// - Throws: `CoreAudioTapRecorderError.osStatus` if the underlying Core Media call returns an error; `CoreAudioTapRecorderError.setupFailed` if no format description is produced.
    private func makeFormatDescription(from format: AudioStreamBasicDescription) throws -> CMAudioFormatDescription {
        var format = format
        var description: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &format,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &description
        )
        try checkStatus(status, context: "create Core Audio tap format description")
        guard let description else {
            throw CoreAudioTapRecorderError.setupFailed("Core Audio tap format description was not created.")
        }
        return description
    }

    /// Reads the audio stream format for the specified Core Audio process tap.
    /// - Parameter tapID: The `AudioObjectID` of the process tap to query.
    /// - Returns: The tap's `AudioStreamBasicDescription`.
    /// - Throws: `CoreAudioTapRecorderError.osStatus` if the Core Audio property query fails.
    private func readTapFormat(_ tapID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try checkStatus(
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format),
            context: "read Core Audio tap format"
        )
        return format
    }

    /// Stop hardware capture and destroy the associated Core Audio resources.
    /// 
    /// Stops the aggregate audio device if active, destroys the registered IO proc, destroys the aggregate device and process tap, and resets `ioProcID`, `aggregateDeviceID`, and `tapID` to unknown values. Core Audio call results are ignored.
    private func stopHardware() {
        if aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioDeviceStop(aggregateDeviceID, ioProcID)
        }

        if let ioProcID, aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        ioProcID = nil

        if aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }

        if tapID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    /// Stops hardware capture, waits for any in-flight Core Audio callbacks, optionally cancels and resets writer state, and clears the paused flag.
    /// - Parameter cancelWriting: If `true`, cancels any in-progress AVAssetWriter work and resets writer-related state before clearing pause state.
    private func cleanup(cancelWriting: Bool) {
        stopHardware()
        callbackQueue.sync {}
        if cancelWriting {
            writerQueue.sync {
                writer?.cancelWriting()
                resetWriterStateOnWriterQueue()
            }
        }
        stateLock.withLock {
            _isPaused = false
            pauseStartedAt = nil
        }
    }

    /// Finalizes the current AVAssetWriter session and waits for completion.
    /// 
    /// Marks the system and microphone inputs as finished, invokes the writer's completion handler to finish writing, and records the first write error observed (if any). Returns only after the writer has completed or there is no active writer to finish.
    private func finishWriter() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writerQueue.async { [weak self] in
                guard let self, let writer = self.writer else {
                    continuation.resume()
                    return
                }

                self.systemInput?.markAsFinished()
                self.micInput?.markAsFinished()

                guard writer.status == .writing || writer.status == .unknown else {
                    if writer.status == .failed, let error = writer.error {
                        self.recordWriteError(error)
                    }
                    continuation.resume()
                    return
                }

                writer.finishWriting { [weak self] in
                    if writer.status == .failed, let error = writer.error {
                        self?.recordWriteError(error)
                    }
                    continuation.resume()
                }
            }
        }
    }

    /// Clears the AVAssetWriter, its inputs, cached format description, and related timing state.
    /// - Note: This operation runs synchronously on the internal `writerQueue`, ensuring writer-related state is reset on the writer queue.
    private func resetWriterState() {
        writerQueue.sync {
            resetWriterStateOnWriterQueue()
        }
    }

    /// Reset writer-related references and timing state to their initial (cleared or invalid) values.
    /// - Note: This should be invoked on the `writerQueue`.
    private func resetWriterStateOnWriterQueue() {
        writer = nil
        systemInput = nil
        micInput = nil
        systemFormatDescription = nil
        systemFramePosition = 0
        micStartTime = .invalid
        micPausedDuration = .zero
    }

    /// Records the first write error observed during capture.
    /// - Parameters:
    ///   - error: The write error to record; ignored if a previous error has already been recorded.
    private func recordWriteError(_ error: any Error) {
        stateLock.withLock {
            if _lastWriteError == nil {
                _lastWriteError = error
            }
        }
    }

    /// Validates an `OSStatus` and throws a `CoreAudioTapRecorderError` if it indicates failure.
    /// - Parameters:
    ///   - status: The `OSStatus` result to validate.
    ///   - context: A short description of the operation being performed; included in the thrown error.
    /// - Throws: `CoreAudioTapRecorderError.osStatus(status, context: ...)` when `status` is not `noErr`.
    private func checkStatus(_ status: OSStatus, context: String) throws {
        guard status == noErr else {
            throw CoreAudioTapRecorderError.osStatus(status, context: context)
        }
    }
}

enum CoreAudioTapRecorderError: LocalizedError {
    case unavailable
    case setupFailed(String)
    case osStatus(OSStatus, context: String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "System Audio (No Screen Sharing) requires macOS 14.2 or later."
        case let .setupFailed(message):
            return message
        case let .osStatus(status, context):
            return "Could not \(context) (status \(status))."
        }
    }
}

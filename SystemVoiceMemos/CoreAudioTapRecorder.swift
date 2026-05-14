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

    private func frameCount(from audioBufferList: UnsafePointer<AudioBufferList>) -> UInt32 {
        guard clientFormat.mBytesPerFrame > 0 else { return 0 }
        guard audioBufferList.pointee.mNumberBuffers > 0 else { return 0 }
        let firstBuffer = audioBufferList.pointee.mBuffers
        return firstBuffer.mDataByteSize / clientFormat.mBytesPerFrame
    }

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

        guard writer.startWriting() else {
            throw writer.error ?? CoreAudioTapRecorderError.setupFailed("Could not start Core Audio asset writer.")
        }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.systemInput = systemInput
        self.micInput = micInput
        systemFramePosition = 0
        micStartTime = .invalid
        micPausedDuration = .zero
    }

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

    private func resetWriterState() {
        writerQueue.sync {
            resetWriterStateOnWriterQueue()
        }
    }

    private func resetWriterStateOnWriterQueue() {
        writer = nil
        systemInput = nil
        micInput = nil
        systemFormatDescription = nil
        systemFramePosition = 0
        micStartTime = .invalid
        micPausedDuration = .zero
    }

    private func recordWriteError(_ error: any Error) {
        stateLock.withLock {
            if _lastWriteError == nil {
                _lastWriteError = error
            }
        }
    }

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

//
//  CoreAudioTapRecorder.swift
//  SystemVoiceMemos
//

import AudioToolbox
import CoreAudio
import Foundation

@available(macOS 14.2, *)
final class CoreAudioTapRecorder {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var extAudioFile: ExtAudioFileRef?
    private var clientFormat = AudioStreamBasicDescription()
    private var isPaused = false

    func startRecording(to url: URL, bitRate: Int) throws {
        cleanup()

        do {
            let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
            tapDescription.name = "SystemVoiceMemos System Audio"
            tapDescription.uuid = UUID()
            tapDescription.isPrivate = true
            tapDescription.muteBehavior = .unmuted

            try checkStatus(
                AudioHardwareCreateProcessTap(tapDescription, &tapID),
                context: "create Core Audio process tap"
            )

            clientFormat = try readTapFormat(tapID)
            try createAggregateDevice(tapUUID: tapDescription.uuid)
            try createAudioFile(at: url, bitRate: bitRate)
            try createIOProc()
            try checkStatus(AudioDeviceStart(aggregateDeviceID, ioProcID), context: "start Core Audio tap device")
        } catch {
            cleanup()
            throw error
        }
    }

    func pauseRecording() {
        guard !isPaused else { return }
        if aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioDeviceStop(aggregateDeviceID, ioProcID)
        }
        isPaused = true
    }

    func resumeRecording() throws {
        guard isPaused else { return }
        try checkStatus(AudioDeviceStart(aggregateDeviceID, ioProcID), context: "resume Core Audio tap device")
        isPaused = false
    }

    func stopRecording() {
        cleanup()
    }

    private func createAggregateDevice(tapUUID: UUID) throws {
        let tapDescription: [String: Any] = [
            kAudioSubTapUIDKey: tapUUID.uuidString,
            kAudioSubTapDriftCompensationKey: 1,
            kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationLowQuality,
        ]

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SystemVoiceMemos Tap",
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

    private func createAudioFile(at url: URL, bitRate: Int) throws {
        var fileFormat = AudioStreamBasicDescription(
            mSampleRate: clientFormat.mSampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: max(clientFormat.mChannelsPerFrame, 1),
            mBitsPerChannel: 0,
            mReserved: 0
        )

        try checkStatus(
            ExtAudioFileCreateWithURL(
                url as CFURL,
                kAudioFileM4AType,
                &fileFormat,
                nil,
                AudioFileFlags.eraseFile.rawValue,
                &extAudioFile
            ),
            context: "create Core Audio tap output file"
        )

        guard let extAudioFile else {
            throw CoreAudioTapRecorderError.setupFailed("Core Audio tap output file was not created.")
        }

        var writableClientFormat = clientFormat
        try checkStatus(
            ExtAudioFileSetProperty(
                extAudioFile,
                kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                &writableClientFormat
            ),
            context: "configure Core Audio tap client format"
        )

        var audioConverter: AudioConverterRef?
        var converterSize = UInt32(MemoryLayout<AudioConverterRef>.size)
        if ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_AudioConverter, &converterSize, &audioConverter) == noErr,
           let audioConverter
        {
            var bitRate = UInt32(bitRate)
            AudioConverterSetProperty(audioConverter, kAudioConverterEncodeBitRate, 4, &bitRate)
        }

        try checkStatus(
            ExtAudioFileWriteAsync(extAudioFile, 0, nil),
            context: "prime Core Audio async file writer"
        )
    }

    private func createIOProc() throws {
        guard extAudioFile != nil else {
            throw CoreAudioTapRecorderError.setupFailed("Core Audio tap file writer is missing.")
        }

        let callbackQueue = DispatchQueue(label: "SystemVoiceMemos.CoreAudioTap.IO")
        let block: AudioDeviceIOBlock = { [weak self] _, inputData, _, _, _ in
            guard let self,
                  !self.isPaused,
                  let extAudioFile = self.extAudioFile
            else {
                return
            }

            let frameCount = self.frameCount(from: inputData)
            guard frameCount > 0 else { return }

            let status = ExtAudioFileWriteAsync(extAudioFile, frameCount, inputData)
            if status != noErr {
                print("Core Audio tap write error:", status)
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

    private func cleanup() {
        if aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioDeviceStop(aggregateDeviceID, ioProcID)
        }

        if let ioProcID, aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        ioProcID = nil

        if let extAudioFile {
            _ = ExtAudioFileDispose(extAudioFile)
        }
        extAudioFile = nil

        if aggregateDeviceID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }

        if tapID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }

        isPaused = false
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

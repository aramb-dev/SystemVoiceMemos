//
//  SystemAudioRecorder.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/9/25.
//

import Foundation
import AVFoundation
import CoreAudio

final class SystemAudioRecorder: NSObject {
    private var audioFile: AVAudioFile?
    private var tap: MTAudioProcessingTap?

    func startRecording(to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        
        // Create the audio tap
        var tapRef: MTAudioProcessingTap?
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            init: { _, _ in },
            finalize: { _ in },
            prepare: { _, _, _ in },
            unprepare: { _ in },
            process: { tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut in
                guard let unmanaged = MTAudioProcessingTapGetStorage(tap) else { return }
                let recorder = Unmanaged<SystemAudioRecorder>.fromOpaque(unmanaged).takeUnretainedValue()
                
                var localFlags: MTAudioProcessingTapFlags = []
                var frameCount = numberFrames
                MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, &localFlags, nil, &frameCount)
                numberFramesOut.pointee = frameCount
                flagsOut.pointee = localFlags

                // write to file
                let buffer = AVAudioPCMBuffer(pcmFormat: recorder.audioFile!.processingFormat, frameCapacity: AVAudioFrameCount(frameCount))!
                buffer.frameLength = buffer.frameCapacity
                try? recorder.audioFile?.write(from: buffer)
            }
        )

        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tapRef)
        if status != noErr { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }

        self.tap = tapRef
        print("System audio recording started")
    }

    func stopRecording() {
        tap = nil
        audioFile = nil
        print("System audio recording stopped")
    }
}

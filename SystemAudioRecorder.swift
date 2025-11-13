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

    private var isRecording = false
    private var startTime: CMTime = .zero
    private var recordingStartDate: Date?
    private var durationTimer: Timer?

    // Published property for real-time duration tracking
    @Published var currentRecordingDuration: TimeInterval = 0

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
        writer.startSession(atSourceTime: .zero)
        print("📝 Writer started")

        print("🚀 Starting capture...")
        try await stream.startCapture()
        print("✅ Capture started successfully!")

        isRecording = true

        // Start real-time duration tracking
        recordingStartDate = Date()
        currentRecordingDuration = 0
        startDurationTimer()
    }

    private func startDurationTimer() {
        // Update duration every 0.1 seconds for smooth UI updates
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.recordingStartDate else { return }
            Task { @MainActor in
                self.currentRecordingDuration = Date().timeIntervalSince(startDate)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartDate = nil
        currentRecordingDuration = 0
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false

        // Stop duration tracking
        stopDurationTimer()

        do {
            try await stream?.stopCapture()
        } catch {
            print("stopCapture error:", error)
        }

        stream = nil

        audioInput?.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer?.finishWriting {
                continuation.resume()
            }
        }

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
                _ = input.append(sampleBuffer)
            }
        }
    }
}

// MARK: - SCStreamDelegate

extension SystemAudioRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error:", error)
    }
}

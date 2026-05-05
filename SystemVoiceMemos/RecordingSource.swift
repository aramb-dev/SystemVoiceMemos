//
//  RecordingSource.swift
//  SystemVoiceMemos
//

import Foundation

enum RecordingSource: String, CaseIterable, Identifiable {
    case coreAudioTap
    case legacyScreenCapture
    case microphoneOnly

    var id: String {
        rawValue
    }

    // Override to hide coreAudioTap on macOS < 14.2 where the tap API is unavailable.
    static var allCases: [RecordingSource] {
        if #available(macOS 14.2, *) {
            return [.coreAudioTap, .legacyScreenCapture, .microphoneOnly]
        }
        return [.legacyScreenCapture, .microphoneOnly]
    }

    var title: String {
        switch self {
        case .coreAudioTap:
            return "System Audio (No Screen Sharing)"
        case .legacyScreenCapture:
            return "System Audio (Legacy)"
        case .microphoneOnly:
            return "Microphone Only"
        }
    }

    var detail: String {
        switch self {
        case .coreAudioTap:
            return "Captures computer audio with Core Audio taps and should not show macOS screen sharing."
        case .legacyScreenCapture:
            return "Uses ScreenCaptureKit and may show macOS screen-sharing UI."
        case .microphoneOnly:
            return "Records regular microphone input, like ChatGPT voice mode."
        }
    }

    static var defaultRawValue: String {
        if #available(macOS 14.2, *) {
            return RecordingSource.coreAudioTap.rawValue
        }
        return RecordingSource.legacyScreenCapture.rawValue
    }

    static var current: RecordingSource {
        let stored = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.recordingSource)
        // Validate against allCases so a persisted coreAudioTap on macOS < 14.2
        // automatically falls back to legacyScreenCapture instead of failing at start.
        if let source = stored.flatMap(RecordingSource.init(rawValue:)),
           allCases.contains(source)
        {
            return source
        }
        return RecordingSource(rawValue: defaultRawValue) ?? .legacyScreenCapture
    }
}

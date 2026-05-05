//
//  RecordingSource.swift
//  SystemVoiceMemos
//

import Foundation

enum RecordingSource: String, CaseIterable, Identifiable {
    case coreAudioTap
    case legacyScreenCapture
    case microphoneOnly

    var id: String { rawValue }

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
        let rawValue = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.recordingSource)
            ?? defaultRawValue
        return RecordingSource(rawValue: rawValue) ?? RecordingSource(rawValue: defaultRawValue) ?? .legacyScreenCapture
    }
}

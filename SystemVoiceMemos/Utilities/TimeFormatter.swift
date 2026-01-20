//
//  TimeFormatter.swift
//  SystemVoiceMemos
//

import Foundation

enum TimeFormatter {
    /// Formats seconds as "M:SS" (e.g., "3:45")
    static func format(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    /// Formats seconds as "MM:SS.cc" for recording display (e.g., "03:45.12")
    static func formatRecordingDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centiseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
    
    /// Formats seconds as "0:00" for playback controls
    static func formatPlayback(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

//
//  SystemAudioPlayer.swift
//  SystemVoiceMemos
//
//  Created by GPT-5 Codex on 10/8/25.
//

import Foundation
import AVFoundation

@MainActor
final class PlaybackManager: NSObject, ObservableObject {

    enum Phase {
        case stopped
        case playing
        case paused
    }

    struct PlaybackError: Identifiable {
        let id = UUID()
        let message: String
    }

    private struct RecordingInfo {
        let id: UUID
        let title: String
        let url: URL
    }

    @Published private(set) var phase: Phase = .stopped
    @Published private(set) var activeRecordingID: UUID?
    @Published private(set) var selectedRecordingID: UUID?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var volume: Float = 1.0
    @Published var error: PlaybackError?

    private var selectedRecording: RecordingInfo?
    private var player: AVAudioPlayer?
    private var timer: Timer?

    var isPlaying: Bool { phase == .playing }
    var hasSelection: Bool { selectedRecording != nil }
    var hasActivePlayer: Bool { player != nil }
    var canPlaySelection: Bool { hasSelection }

    func select(recording: RecordingEntity?, autoPlay: Bool = false) {
        guard let recording else {
            selectedRecording = nil
            selectedRecordingID = nil
            return
        }

        do {
            let info = try makeInfo(from: recording)
            selectedRecording = info
            selectedRecordingID = info.id

            if autoPlay {
                play(info: info)
            }
        } catch {
            selectedRecording = nil
            selectedRecordingID = nil
            presentError(message: "Missing audio file for \(recording.title)")
        }
    }

    func playSelected() {
        guard let info = selectedRecording else {
            presentError(message: "Select a recording to play")
            return
        }

        // If a different item is already playing, switch.
        if activeRecordingID != info.id {
            play(info: info)
            return
        }

        if let player, !player.isPlaying {
            resumePlayback(player: player)
        } else if player == nil {
            play(info: info)
        }
    }

    func togglePlayPause() {
        guard let player else {
            if selectedRecording != nil {
                playSelected()
            }
            return
        }

        if player.isPlaying {
            pausePlayback(player: player)
        } else {
            resumePlayback(player: player)
        }
    }

    func stop() {
        guard let player else { return }
        player.stop()
        resetPlayerState()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    func skip(by interval: TimeInterval) {
        guard let player else { return }
        let target = player.currentTime + interval
        seek(to: target)
    }

    func setVolume(_ value: Float) {
        let clamped = max(0, min(value, 1))
        volume = clamped
        player?.volume = clamped
    }

    func handleDeletion(of recordingID: UUID) {
        if activeRecordingID == recordingID {
            stop()
        }
        if selectedRecordingID == recordingID {
            selectedRecording = nil
            selectedRecordingID = nil
        }
    }

    private func play(info: RecordingInfo) {
        if let player {
            player.stop()
        }
        resetPlayerState()

        do {
            let player = try AVAudioPlayer(contentsOf: info.url)
            player.delegate = self
            player.volume = volume
            player.prepareToPlay()
            player.play()

            self.player = player
            self.activeRecordingID = info.id
            self.phase = .playing
            self.duration = player.duration
            self.currentTime = player.currentTime
            startTimer()
        } catch {
            presentError(message: "Unable to play \(info.title)")
            resetPlayerState()
        }
    }

    private func pausePlayback(player: AVAudioPlayer) {
        player.pause()
        phase = .paused
        stopTimer()
    }

    private func resumePlayback(player: AVAudioPlayer) {
        player.play()
        phase = .playing
        startTimer()
    }

    private func resetPlayerState() {
        stopTimer()
        player = nil
        phase = .stopped
        activeRecordingID = nil
        currentTime = 0
        duration = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.syncWithPlayer()
        }
    }

    private func syncWithPlayer() {
        guard let player else {
            stopTimer()
            return
        }
        currentTime = player.currentTime
        duration = player.duration
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func makeInfo(from recording: RecordingEntity) throws -> RecordingInfo {
        let dir = try AppDirectories.recordingsDir()
        let url = dir.appendingPathComponent(recording.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return RecordingInfo(id: recording.id, title: recording.title, url: url)
    }

    private func presentError(message: String) {
        error = PlaybackError(message: message)
    }
}

extension PlaybackManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}

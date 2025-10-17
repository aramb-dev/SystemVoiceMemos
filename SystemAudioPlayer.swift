//
//  SystemAudioPlayer.swift
//  SystemVoiceMemos
//
//  Created by GPT-5 Codex on 10/8/25.
//

import Foundation
import AVFoundation
import MediaPlayer

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
    private var nowPlayingInfo: [String: Any] = [:]
    private var commandTargets: [(command: MPRemoteCommand, token: Any)] = []

    var isPlaying: Bool { phase == .playing }
    var hasSelection: Bool { selectedRecording != nil }
    var hasActivePlayer: Bool { player != nil }
    var canPlaySelection: Bool { hasSelection }

    override init() {
        super.init()
        configureRemoteCommands()
    }

    deinit {
        MainActor.assumeIsolated {
            tearDownRemoteCommands()
        }
    }

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
        guard let player else {
            resetPlayerState(preserveSelection: true)
            return
        }
        player.stop()
        resetPlayerState(preserveSelection: true)
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlayingElapsedTime()
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
        resetPlayerState(preserveSelection: true)

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
            updateNowPlayingInfo(for: info, player: player)
        } catch {
            presentError(message: "Unable to play \(info.title)")
            resetPlayerState(preserveSelection: true)
        }
    }

    private func pausePlayback(player: AVAudioPlayer) {
        player.pause()
        phase = .paused
        stopTimer()
        updateNowPlayingPlaybackState(isPlaying: false)
    }

    private func resumePlayback(player: AVAudioPlayer) {
        player.play()
        phase = .playing
        startTimer()
        updateNowPlayingPlaybackState(isPlaying: true)
    }

    private func resetPlayerState(preserveSelection: Bool = false) {
        stopTimer()
        player = nil
        phase = .stopped
        activeRecordingID = nil
        currentTime = 0
        duration = 0
        if !preserveSelection {
            selectedRecording = nil
            selectedRecordingID = nil
        }
        clearNowPlaying()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.syncWithPlayer()
            }
        }
    }

    private func syncWithPlayer() {
        guard let player else {
            stopTimer()
            return
        }
        currentTime = player.currentTime
        duration = player.duration
        updateNowPlayingElapsedTime()
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

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        let commands: [(MPRemoteCommand, (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus)] = [
            (center.playCommand, { [weak self] _ in self?.handlePlayCommand() ?? .commandFailed }),
            (center.pauseCommand, { [weak self] _ in self?.handlePauseCommand() ?? .commandFailed }),
            (center.togglePlayPauseCommand, { [weak self] _ in self?.handleToggleCommand() ?? .commandFailed }),
            (center.nextTrackCommand, { [weak self] _ in self?.handleSkipForwardCommand() ?? .commandFailed }),
            (center.previousTrackCommand, { [weak self] _ in self?.handleSkipBackwardCommand() ?? .commandFailed })
        ]

        for (command, handler) in commands {
            command.isEnabled = true
            let token = command.addTarget(handler: handler)
            commandTargets.append((command, token))
        }
    }

    private func tearDownRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        for entry in commandTargets {
            entry.command.removeTarget(entry.token)
        }
        commandTargets.removeAll()
        center.togglePlayPauseCommand.isEnabled = false
        center.playCommand.isEnabled = false
        center.pauseCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }

    private func handlePlayCommand() -> MPRemoteCommandHandlerStatus {
        if isPlaying { return .success }
        playSelected()
        return hasSelection ? .success : .noSuchContent
    }

    private func handlePauseCommand() -> MPRemoteCommandHandlerStatus {
        guard hasActivePlayer else { return .noSuchContent }
        if isPlaying {
            togglePlayPause()
        }
        return .success
    }

    private func handleToggleCommand() -> MPRemoteCommandHandlerStatus {
        togglePlayPause()
        return hasSelection || hasActivePlayer ? .success : .noSuchContent
    }

    private func handleSkipForwardCommand() -> MPRemoteCommandHandlerStatus {
        guard hasActivePlayer else { return .noSuchContent }
        skip(by: 15)
        return .success
    }

    private func handleSkipBackwardCommand() -> MPRemoteCommandHandlerStatus {
        guard hasActivePlayer else { return .noSuchContent }
        skip(by: -15)
        return .success
    }

    private func updateNowPlayingInfo(for info: RecordingInfo, player: AVAudioPlayer) {
        var infoDictionary: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        if #available(macOS 14.0, *) {
            infoDictionary[MPMediaItemPropertyArtist] = "System Voice Memos"
        }
        nowPlayingInfo = infoDictionary
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        updateNowPlayingPlaybackState(isPlaying: true)
    }

    private func updateNowPlayingElapsedTime() {
        guard let player else { return }
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingPlaybackState(isPlaying: Bool) {
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        if #available(macOS 10.12.2, *) {
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        }
    }

    private func clearNowPlaying() {
        nowPlayingInfo.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if #available(macOS 10.12.2, *) {
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }
}

extension PlaybackManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}

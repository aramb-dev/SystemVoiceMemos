//
//  SystemAudioPlayer.swift
//  SystemVoiceMemos
//
//  Created by GPT-5 Codex on 10/8/25.
//
//  Manages audio playback with AVAudioPlayer and MediaPlayer integration.
//  Provides playback controls, progress tracking, and Now Playing info.
//

import Foundation
import AVFoundation
import MediaPlayer

/// Manages audio playback for recordings
///
/// This class:
/// - Plays audio files using AVAudioPlayer
/// - Integrates with macOS Now Playing center
/// - Handles remote control commands (play, pause, skip)
/// - Provides real-time playback progress
/// - Manages volume and seeking
@MainActor
final class PlaybackManager: NSObject, ObservableObject {

    // MARK: - Types
    
    /// Playback phase enumeration
    enum Phase {
        case stopped
        case playing
        case paused
    }

    /// Playback error for UI presentation
    struct PlaybackError: Identifiable {
        let id = UUID()
        let message: String
    }

    /// Internal recording information
    private struct RecordingInfo {
        let id: UUID
        let title: String
        let url: URL
    }

    // MARK: - Published State
    
    /// Current playback phase
    @Published private(set) var phase: Phase = .stopped
    
    /// ID of the recording currently being played
    @Published private(set) var activeRecordingID: UUID?
    
    /// ID of the recording selected for playback
    @Published private(set) var selectedRecordingID: UUID?
    
    /// Current playback position in seconds
    @Published private(set) var currentTime: TimeInterval = 0
    
    /// Total duration of the current recording in seconds
    @Published private(set) var duration: TimeInterval = 0
    
    /// Current volume level (0.0 to 1.0)
    @Published private(set) var volume: Float = 1.0
    
    /// Current playback error, if any
    @Published var error: PlaybackError?

    // MARK: - Private Properties
    
    /// Currently selected recording information
    private var selectedRecording: RecordingInfo?
    
    /// The active audio player instance
    private var player: AVAudioPlayer?
    
    /// Timer for updating playback progress
    private var timer: Timer?
    
    /// Now Playing metadata dictionary
    private var nowPlayingInfo: [String: Any] = [:]
    
    /// Remote command targets for cleanup
    private var commandTargets: [(command: MPRemoteCommand, token: Any)] = []

    // MARK: - Computed Properties
    
    /// Whether audio is currently playing
    var isPlaying: Bool { phase == .playing }
    
    /// Whether a recording is selected
    var hasSelection: Bool { selectedRecording != nil }
    
    /// Whether an active player exists
    var hasActivePlayer: Bool { player != nil }
    
    /// Whether the selected recording can be played
    var canPlaySelection: Bool { hasSelection }

    // MARK: - Initialization
    
    override init() {
        super.init()
        configureRemoteCommands()
    }

    deinit {
        MainActor.assumeIsolated {
            tearDownRemoteCommands()
        }
    }

    // MARK: - Selection Management
    
    /// Selects a recording for playback
    ///
    /// - Parameters:
    ///   - recording: The recording to select, or nil to clear selection
    ///   - autoPlay: Whether to automatically start playback
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

    // MARK: - Playback Control
    
    /// Plays the currently selected recording
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

    /// Toggles between play and pause states
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

    /// Stops playback and resets state
    func stop() {
        guard let player else {
            resetPlayerState(preserveSelection: true)
            return
        }
        player.stop()
        resetPlayerState(preserveSelection: true)
    }

    /// Seeks to a specific time position
    ///
    /// - Parameter time: The target time in seconds
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
        updateNowPlayingElapsedTime()
    }

    /// Skips forward or backward by an interval
    ///
    /// - Parameter interval: The skip interval in seconds (positive or negative)
    func skip(by interval: TimeInterval) {
        guard let player else { return }
        let target = player.currentTime + interval
        seek(to: target)
    }

    /// Sets the playback volume
    ///
    /// - Parameter value: Volume level from 0.0 to 1.0
    func setVolume(_ value: Float) {
        let clamped = max(0, min(value, 1))
        volume = clamped
        player?.volume = clamped
    }

    /// Handles deletion of a recording
    ///
    /// Stops playback if the deleted recording is active or selected.
    ///
    /// - Parameter recordingID: The ID of the deleted recording
    func handleDeletion(of recordingID: UUID) {
        if activeRecordingID == recordingID {
            stop()
        }
        if selectedRecordingID == recordingID {
            selectedRecording = nil
            selectedRecordingID = nil
        }
    }

    // MARK: - Private Playback Methods
    
    /// Starts playing a recording
    ///
    /// - Parameter info: The recording information
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

    /// Pauses the audio player
    ///
    /// - Parameter player: The audio player to pause
    private func pausePlayback(player: AVAudioPlayer) {
        player.pause()
        phase = .paused
        stopTimer()
        updateNowPlayingPlaybackState(isPlaying: false)
    }

    /// Resumes the audio player
    ///
    /// - Parameter player: The audio player to resume
    private func resumePlayback(player: AVAudioPlayer) {
        player.play()
        phase = .playing
        startTimer()
        updateNowPlayingPlaybackState(isPlaying: true)
    }

    /// Resets player state to idle
    ///
    /// - Parameter preserveSelection: Whether to keep the current selection
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

    // MARK: - Progress Tracking
    
    /// Starts the progress update timer
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.syncWithPlayer()
            }
        }
    }

    /// Syncs published state with player state
    private func syncWithPlayer() {
        guard let player else {
            stopTimer()
            return
        }
        currentTime = player.currentTime
        duration = player.duration
        updateNowPlayingElapsedTime()
    }

    /// Stops the progress update timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Helper Methods
    
    /// Creates recording info from an entity
    ///
    /// - Parameter recording: The recording entity
    /// - Returns: Recording information
    /// - Throws: Error if file doesn't exist
    private func makeInfo(from recording: RecordingEntity) throws -> RecordingInfo {
        let dir = try AppDirectories.recordingsDir()
        let url = dir.appendingPathComponent(recording.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return RecordingInfo(id: recording.id, title: recording.title, url: url)
    }

    /// Presents an error to the user
    ///
    /// - Parameter message: The error message
    private func presentError(message: String) {
        error = PlaybackError(message: message)
    }

    // MARK: - Remote Control
    
    /// Configures remote control command handlers
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

    /// Removes remote control command handlers
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

    /// Handles remote play command
    ///
    /// - Returns: Command handler status
    private func handlePlayCommand() -> MPRemoteCommandHandlerStatus {
        if isPlaying { return .success }
        playSelected()
        return hasSelection ? .success : .noSuchContent
    }

    /// Handles remote pause command
    ///
    /// - Returns: Command handler status
    private func handlePauseCommand() -> MPRemoteCommandHandlerStatus {
        guard hasActivePlayer else { return .noSuchContent }
        if isPlaying {
            togglePlayPause()
        }
        return .success
    }

    /// Handles remote toggle play/pause command
    ///
    /// - Returns: Command handler status
    private func handleToggleCommand() -> MPRemoteCommandHandlerStatus {
        togglePlayPause()
        return hasSelection || hasActivePlayer ? .success : .noSuchContent
    }

    /// Handles remote skip forward command
    ///
    /// - Returns: Command handler status
    private func handleSkipForwardCommand() -> MPRemoteCommandHandlerStatus {
        guard hasActivePlayer else { return .noSuchContent }
        skip(by: 15)
        return .success
    }

    /// Handles remote skip backward command
    ///
    /// - Returns: Command handler status
    private func handleSkipBackwardCommand() -> MPRemoteCommandHandlerStatus {
        guard hasActivePlayer else { return .noSuchContent }
        skip(by: -15)
        return .success
    }

    // MARK: - Now Playing
    
    /// Updates Now Playing metadata
    ///
    /// - Parameters:
    ///   - info: The recording information
    ///   - player: The audio player
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

    /// Updates Now Playing elapsed time
    private func updateNowPlayingElapsedTime() {
        guard let player else { return }
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    /// Updates Now Playing playback state
    ///
    /// - Parameter isPlaying: Whether audio is playing
    private func updateNowPlayingPlaybackState(isPlaying: Bool) {
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        if #available(macOS 10.12.2, *) {
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        }
    }

    /// Clears Now Playing metadata
    private func clearNowPlaying() {
        nowPlayingInfo.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if #available(macOS 10.12.2, *) {
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension PlaybackManager: AVAudioPlayerDelegate {
    /// Called when audio finishes playing
    ///
    /// - Parameters:
    ///   - player: The audio player
    ///   - flag: Whether playback finished successfully
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}

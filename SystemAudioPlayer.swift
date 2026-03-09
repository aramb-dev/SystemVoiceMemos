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

    /// Export mode for recordings
    enum ExportMode {
        case systemOnly
        case micOnly
        case bothMixed
    }

    /// Internal recording information
    private struct RecordingInfo {
        let id: UUID
        let title: String
        let url: URL
        let hasMicTrack: Bool
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
    
    /// System audio track volume
    @Published var systemVolume: Float = 1.0 {
        didSet { updateAudioMix() }
    }
    
    /// Microphone track volume
    @Published var micVolume: Float = 1.0 {
        didSet { updateAudioMix() }
    }

    /// Whether the selected recording has a mic track
    @Published private(set) var hasMicTrack: Bool = false
    
    /// Current playback error, if any
    @Published var error: PlaybackError?

    // MARK: - Private Properties
    
    /// Currently selected recording information
    private var selectedRecording: RecordingInfo?
    
    /// The active audio player instance
    private var player: AVPlayer?
    
    /// Audio mix for independent track volume control
    private var audioMix: AVMutableAudioMix?
    
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
            stop()
            selectedRecording = nil
            selectedRecordingID = nil
            hasMicTrack = false
            return
        }

        do {
            let info = try makeInfo(from: recording)

            // Stop the old player when switching to a different recording
            if activeRecordingID != nil && activeRecordingID != info.id {
                player?.pause()
                resetPlayerState(preserveSelection: true)
            }

            selectedRecording = info
            selectedRecordingID = info.id
            hasMicTrack = info.hasMicTrack

            if autoPlay {
                play(info: info)
            }
        } catch {
            selectedRecording = nil
            selectedRecordingID = nil
            hasMicTrack = false
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

        if let player, player.rate == 0 {
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

        if player.rate != 0 {
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
        player.pause()
        resetPlayerState(preserveSelection: true)
    }

    /// Seeks to a specific time position
    ///
    /// - Parameter time: The target time in seconds
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let target = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateNowPlayingElapsedTime()
    }

    /// Skips forward or backward by an interval
    ///
    /// - Parameter interval: The skip interval in seconds (positive or negative)
    func skip(by interval: TimeInterval) {
        guard let player else { return }
        let target = CMTimeGetSeconds(player.currentTime()) + interval
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
            hasMicTrack = false
        }
    }

    // MARK: - Private Playback Methods
    
    /// Starts playing a recording
    ///
    /// - Parameter info: The recording information
    private func play(info: RecordingInfo) {
        if let player {
            player.pause()
        }
        resetPlayerState(preserveSelection: true)

        let asset = AVAsset(url: info.url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Setup initial audio mix
        setupAudioMix(for: playerItem, asset: asset)
        
        let player = AVPlayer(playerItem: playerItem)
        player.volume = volume
        player.play()

        self.player = player
        self.activeRecordingID = info.id
        self.phase = .playing
        
        // Use a Task to load duration
        Task {
            if let duration = try? await asset.load(.duration) {
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(duration)
                }
            }
        }
        
        self.currentTime = 0
        startTimer()
        updateNowPlayingInfo(for: info, player: player)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    @objc private func playerItemDidFinishPlaying() {
        Task { @MainActor in
            self.stop()
        }
    }

    /// Pauses the audio player
    ///
    /// - Parameter player: The audio player to pause
    private func pausePlayback(player: AVPlayer) {
        player.pause()
        phase = .paused
        stopTimer()
        updateNowPlayingPlaybackState(isPlaying: false)
    }

    /// Resumes the audio player
    ///
    /// - Parameter player: The audio player to resume
    private func resumePlayback(player: AVPlayer) {
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
        audioMix = nil
        phase = .stopped
        activeRecordingID = nil
        currentTime = 0
        duration = 0
        if !preserveSelection {
            selectedRecording = nil
            selectedRecordingID = nil
            hasMicTrack = false
        }
        clearNowPlaying()
    }

    // MARK: - Track Volume Control
    
    private func setupAudioMix(for playerItem: AVPlayerItem, asset: AVAsset) {
        Task {
            let tracks = try? await asset.loadTracks(withMediaType: .audio)
            guard let tracks = tracks else { return }
            
            await MainActor.run {
                let mixParameters = tracks.enumerated().map { index, track -> AVMutableAudioMixInputParameters in
                    let parameters = AVMutableAudioMixInputParameters(track: track)
                    // Track 0 = System, Track 1 = Mic
                    let vol = index == 0 ? self.systemVolume : self.micVolume
                    parameters.setVolume(vol, at: .zero)
                    return parameters
                }
                
                let mix = AVMutableAudioMix()
                mix.inputParameters = mixParameters
                self.audioMix = mix
                playerItem.audioMix = mix
            }
        }
    }
    
    private func updateAudioMix() {
        guard let player = player, let playerItem = player.currentItem, audioMix != nil else { return }
        
        // Simpler: re-create the mix parameters if we have the asset
        guard let asset = playerItem.asset as? AVURLAsset else { return }
        
        Task {
            let tracks = try? await asset.loadTracks(withMediaType: .audio)
            guard let tracks = tracks else { return }
            
            await MainActor.run {
                let mixParameters = tracks.enumerated().map { index, track -> AVMutableAudioMixInputParameters in
                    let parameters = AVMutableAudioMixInputParameters(track: track)
                    let vol = index == 0 ? self.systemVolume : self.micVolume
                    parameters.setVolume(vol, at: .zero)
                    return parameters
                }
                let mix = AVMutableAudioMix()
                mix.inputParameters = mixParameters
                self.audioMix = mix
                playerItem.audioMix = mix
            }
        }
    }

    // MARK: - Export
    
    /// Exports a recording based on the specified mode
    ///
    /// - Parameters:
    ///   - recording: The recording to export
    ///   - mode: The export mode
    ///   - destinationURL: Where to save the exported file
    func exportRecording(_ recording: RecordingEntity, mode: ExportMode, to destinationURL: URL) async throws {
        let info = try makeInfo(from: recording)
        let asset = AVAsset(url: info.url)
        
        let composition = AVMutableComposition()
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        
        switch mode {
        case .systemOnly:
            if let systemTrack = tracks.first {
                let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try await compTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: asset.load(.duration)), of: systemTrack, at: .zero)
            }
        case .micOnly:
            if tracks.count > 1 {
                let micTrack = tracks[1]
                let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try await compTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: asset.load(.duration)), of: micTrack, at: .zero)
            } else {
                throw NSError(domain: "PlaybackManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone track not found"])
            }
        case .bothMixed:
            // Both tracks will be mixed by default if we add them both to the composition
            for track in tracks {
                let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try await compTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: asset.load(.duration)), of: track, at: .zero)
            }
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "PlaybackManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        if exportSession.status == .failed {
            throw exportSession.error ?? NSError(domain: "PlaybackManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
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
        currentTime = CMTimeGetSeconds(player.currentTime())
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
        return RecordingInfo(id: recording.id, title: recording.title, url: url, hasMicTrack: recording.hasMicTrack)
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
    private func updateNowPlayingInfo(for info: RecordingInfo, player: AVPlayer) {
        var infoDictionary: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: CMTimeGetSeconds(player.currentTime()),
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        
        Task {
            if let duration = try? await player.currentItem?.asset.load(.duration) {
                infoDictionary[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(duration)
            }
            
            await MainActor.run {
                if #available(macOS 14.0, *) {
                    infoDictionary[MPMediaItemPropertyArtist] = "System Voice Memos"
                }
                nowPlayingInfo = infoDictionary
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                updateNowPlayingPlaybackState(isPlaying: true)
            }
        }
    }

    /// Updates Now Playing elapsed time
    private func updateNowPlayingElapsedTime() {
        guard let player else { return }
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(player.currentTime())
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

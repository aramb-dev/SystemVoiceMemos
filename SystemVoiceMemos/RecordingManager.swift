//
//  RecordingManager.swift
//  SystemVoiceMemos
//
//  Orchestrates the recording workflow including the floating panel UI.
//  Manages recording lifecycle and coordinates with SystemAudioRecorder.
//

import AVFoundation
import Foundation
import SwiftData

/// Manages the recording workflow and UI coordination
///
/// This class:
/// - Coordinates recording start/stop/restart operations
/// - Manages the floating recording panel
/// - Handles window animations during recording
/// - Creates and finalizes recording entities in SwiftData
/// - Provides screen capture exclusion control
@MainActor
@Observable
class RecordingManager {
    // MARK: - Properties

    /// Whether a recording is currently active
    var isRecording = false {
        didSet { AppState.shared.isRecording = isRecording }
    }

    /// User-facing error message when recording fails to start
    var lastError: String?

    /// The recording entity being created (not yet finalized)
    private(set) var pendingRecording: RecordingEntity?

    /// The audio recorder instance
    private let recorder = SystemAudioRecorder()

    /// The floating recording panel UI
    private let floatingPanel = FloatingRecordingPanel()

    /// Handles main window animations
    private let windowAnimator = WindowAnimator()

    // MARK: - Public Accessors

    /// Access to the recorder for UI binding
    var recorderInstance: SystemAudioRecorder {
        recorder
    }

    /// Access to the floating panel for UI binding
    var floatingPanelInstance: FloatingRecordingPanel {
        floatingPanel
    }

    /// Access to the window animator for UI binding
    var windowAnimatorInstance: WindowAnimator {
        windowAnimator
    }

    // MARK: - Recording Flow

    /// Starts a new recording workflow
    ///
    /// This method:
    /// 1. Creates a new recording entity
    /// 2. Starts audio capture
    /// 3. Animates the main window to a bar
    /// 4. Shows the floating recording panel
    ///
    /// - Parameters:
    ///   - modelContext: SwiftData context for persistence
    ///   - hideFromScreenSharing: Whether to exclude from screen capture
    ///   - onComplete: Callback when recording stops
    func startRecordingFlow(
        modelContext: ModelContext,
        hideFromScreenSharing: Bool,
        onComplete: @escaping () -> Void
    ) async {
        // Prevent concurrent executions - check manager state first
        guard !isRecording else { return }
        guard !recorder.isRecording else { return }

        guard await startNewRecording(modelContext: modelContext) else { return }
        isRecording = true

        floatingPanel.onStop = { [weak self] in
            Task { @MainActor in
                await self?.stopRecordingFlow(modelContext: modelContext)
                onComplete()
            }
        }

        floatingPanel.onRestart = { [weak self] in
            Task { @MainActor in
                await self?.restartRecordingFlow(modelContext: modelContext)
            }
        }

        floatingPanel.onExpand = { [weak self] in
            Task { @MainActor in
                self?.expandToFullWindow(restoreToolbarIfNeeded: true)
            }
        }

        if UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.minimizeWindowDuringRecording) as? Bool ?? true {
            windowAnimator.shrinkToBar()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            self.showFloatingToolbar(hideFromScreenSharing: hideFromScreenSharing)
        }
    }

    /// Stops the current recording workflow
    ///
    /// This method:
    /// 1. Stops audio capture
    /// 2. Hides the floating panel
    /// 3. Restores the main window
    /// 4. Finalizes the recording with actual duration
    ///
    /// - Parameter modelContext: SwiftData context for persistence
    func stopRecordingFlow(modelContext: ModelContext) async {
        guard recorder.isRecording else { return }

        await recorder.stopRecording()
        isRecording = false
        floatingPanel.hide()

        if windowAnimator.isMinimized {
            windowAnimator.expandToFull()
        } else {
            windowAnimator.restoreWithoutAnimation()
        }

        await finalizePendingRecording(modelContext: modelContext)
    }

    /// Restarts the current recording
    ///
    /// Discards the current recording and starts a new one.
    ///
    /// - Parameter modelContext: SwiftData context for persistence
    func restartRecordingFlow(modelContext: ModelContext) async {
        await recorder.stopRecording()

        if let pending = pendingRecording {
            let fileURL = (try? AppDirectories.recordingsDir())?.appendingPathComponent(pending.fileName)
            if let url = fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(pending)
            pendingRecording = nil
        }

        await startNewRecording(modelContext: modelContext)
        showFloatingToolbar()
    }

    /// Expands from floating panel to full window
    func expandToFullWindow(restoreToolbarIfNeeded: Bool = false) {
        floatingPanel.hide()
        windowAnimator.expandToFull()

        guard restoreToolbarIfNeeded,
              recorder.isRecording,
              UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.restoreToolbarAfterExpand) as? Bool ?? true
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.showFloatingToolbar()
        }
    }

    /// Shows the floating recording toolbar for the active recording.
    func showFloatingToolbar(hideFromScreenSharing: Bool? = nil) {
        guard recorder.isRecording,
              UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.showFloatingRecordingToolbar) as? Bool ?? true
        else { return }

        floatingPanel.show(recorder: recorder)

        if let hideFromScreenSharing {
            floatingPanel.setScreenCaptureExclusion(hideFromScreenSharing)
        }
    }

    /// Sets screen capture exclusion for the floating panel
    ///
    /// - Parameter exclude: Whether to exclude from screen capture
    func setScreenCaptureExclusion(_ exclude: Bool) {
        floatingPanel.setScreenCaptureExclusion(exclude)
    }

    // MARK: - Private Methods

    /// Creates and starts a new recording
    ///
    /// - Parameter modelContext: SwiftData context for persistence
    /// Begins a new audio recording, creates and inserts a corresponding `RecordingEntity`, and prepares the manager to track the in-progress recording.
    ///
    /// Checks and requests microphone permission when required by the selected recording source, starts the recorder writing to a new `.m4a` file in the app recordings directory, inserts a `RecordingEntity` (with `hasMicTrack` set according to the recording source and user preference), and assigns it to `pendingRecording`. On failure this method sets `lastError`.
    /// - Parameters:
    ///   - modelContext: The SwiftData model context used to insert and save the new `RecordingEntity`.
    /// - Returns: `true` if recording was successfully started and a pending entity created, `false` otherwise.
    @discardableResult
    private func startNewRecording(modelContext: ModelContext) async -> Bool {
        // Guard against concurrent calls
        guard !isRecording else { return false }

        let source = RecordingSource.current
        let needsMicrophone = shouldIncludeMicrophone(for: source)

        // Check microphone permission if the selected source needs it.
        if needsMicrophone {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .notDetermined {
                await PermissionManager.shared.requestAudioPermission()
                // Re-check after the prompt — user may have denied.
                let updated = AVCaptureDevice.authorizationStatus(for: .audio)
                if updated != .authorized {
                    lastError = "Microphone access is denied. Please enable it in System Settings."
                    return false
                }
            } else if status == .denied || status == .restricted {
                lastError = "Microphone access is denied. Please enable it in System Settings."
                return false
            }
        }

        do {
            let dir = try AppDirectories.recordingsDir()
            let base = await recordingBaseName()
            let fileName = "\(base).m4a"
            let url = dir.appendingPathComponent(fileName)

            try await recorder.startRecording(to: url)

            let entity = RecordingEntity(
                title: base,
                createdAt: .now,
                duration: 0,
                fileName: fileName,
                hasMicTrack: shouldIncludeMicrophone(for: source)
            )
            modelContext.insert(entity)
            try? modelContext.save()

            pendingRecording = entity
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Builds a recording name based on user naming preferences.
    ///
    /// If location-based naming is enabled, format is:
    /// `Location-YYYY-MM-DD HH.mm.ss`
    /// Otherwise:
    /// `YYYY-MM-DD HH.mm.ss`
    private func recordingBaseName(at date: Date = .now) async -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let timestamp = formatter.string(from: date)

        let defaults = UserDefaults.standard
        let locationNamingEnabled = defaults.bool(forKey: AppConstants.UserDefaultsKeys.locationBasedNaming)
        guard locationNamingEnabled else { return timestamp }

        guard let locationToken = await LocationNamingService.shared.cityToken(), !locationToken.isEmpty else {
            return timestamp
        }
        return "\(locationToken)-\(timestamp)"
    }

    /// Finalizes the pending recording with actual duration
    ///
    /// Reads the audio file to get the actual duration and updates the entity.
    ///
    /// - Parameter modelContext: SwiftData context for persistence
    private func finalizePendingRecording(modelContext: ModelContext) async {
        guard let recording = pendingRecording else {
            pendingRecording = nil
            return
        }

        guard let url = try? recordingURL(for: recording) else {
            pendingRecording = nil
            return
        }

        let asset = AVURLAsset(url: url)
        do {
            let (cmDuration, tracks) = try await asset.load(.duration, .tracks)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite, seconds > 0.01 {
                recording.duration = seconds
            }
            recording.hasMicTrack = tracks.count > 1 || recording.hasMicTrack
            try? modelContext.save()
        } catch {
            print("duration load error:", error)
        }
        pendingRecording = nil
    }

    /// Gets the file URL for a recording
    ///
    /// - Parameter recording: The recording entity
    /// - Returns: The file URL
    /// - Throws: Error if recordings directory cannot be accessed
    private func recordingURL(for recording: RecordingEntity) throws -> URL {
        let dir = try AppDirectories.recordingsDir()
        return dir.appendingPathComponent(recording.fileName)
    }

    private func shouldIncludeMicrophone(for source: RecordingSource) -> Bool {
        let micEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.includeMicrophone)
        return source == .microphoneOnly
            || ((source == .coreAudioTap || source == .legacyScreenCapture) && micEnabled)
    }
}

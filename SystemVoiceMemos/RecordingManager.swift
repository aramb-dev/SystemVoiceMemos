//
//  RecordingManager.swift
//  SystemVoiceMemos
//
//  Orchestrates the recording workflow including the floating panel UI.
//  Manages recording lifecycle and coordinates with SystemAudioRecorder.
//

import Foundation
import SwiftData
import AVFoundation

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
    var isRecording = false
    
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
    var recorderInstance: SystemAudioRecorder { recorder }
    
    /// Access to the floating panel for UI binding
    var floatingPanelInstance: FloatingRecordingPanel { floatingPanel }
    
    /// Access to the window animator for UI binding
    var windowAnimatorInstance: WindowAnimator { windowAnimator }
    
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
        
        await startNewRecording(modelContext: modelContext)
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
                self?.expandToFullWindow()
            }
        }
        
        windowAnimator.shrinkToBar()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            self.floatingPanel.show(recorder: self.recorder)
            self.floatingPanel.setScreenCaptureExclusion(hideFromScreenSharing)
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
        floatingPanel.show(recorder: recorder)
    }
    
    /// Expands from floating panel to full window
    func expandToFullWindow() {
        floatingPanel.hide()
        windowAnimator.expandToFull()
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
    private func startNewRecording(modelContext: ModelContext) async {
        // Guard against concurrent calls
        guard !isRecording else { return }
        
        do {
            let dir = try AppDirectories.recordingsDir()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
            let base = formatter.string(from: .now)
            let fileName = "\(base).m4a"
            let url = dir.appendingPathComponent(fileName)

            try await recorder.startRecording(to: url)

            let entity = RecordingEntity(
                title: base,
                createdAt: .now,
                duration: 0,
                fileName: fileName
            )
            modelContext.insert(entity)
            try? modelContext.save()

            pendingRecording = entity
            // Note: isRecording is set to true in startRecordingFlow, not here
        } catch {
            print("startRecording error:", error)
        }
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
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0.01 {
                recording.duration = seconds
                try? modelContext.save()
            }
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
}

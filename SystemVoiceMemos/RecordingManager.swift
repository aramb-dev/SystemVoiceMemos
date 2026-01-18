//
//  RecordingManager.swift
//  SystemVoiceMemos
//

import Foundation
import SwiftData
import AVFoundation

@MainActor
@Observable
class RecordingManager {
    var isRecording = false
    private(set) var pendingRecording: RecordingEntity?
    
    private let recorder = SystemAudioRecorder()
    private let floatingPanel = FloatingRecordingPanel()
    private let windowAnimator = WindowAnimator()
    
    var recorderInstance: SystemAudioRecorder { recorder }
    var floatingPanelInstance: FloatingRecordingPanel { floatingPanel }
    var windowAnimatorInstance: WindowAnimator { windowAnimator }
    
    func startRecordingFlow(
        modelContext: ModelContext,
        hideFromScreenSharing: Bool,
        onComplete: @escaping () -> Void
    ) async {
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
    
    func expandToFullWindow() {
        floatingPanel.hide()
        windowAnimator.expandToFull()
    }
    
    func setScreenCaptureExclusion(_ exclude: Bool) {
        floatingPanel.setScreenCaptureExclusion(exclude)
    }
    
    // MARK: - Private
    
    private func startNewRecording(modelContext: ModelContext) async {
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
            isRecording = true
        } catch {
            print("startRecording error:", error)
        }
    }

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
    
    private func recordingURL(for recording: RecordingEntity) throws -> URL {
        let dir = try AppDirectories.recordingsDir()
        return dir.appendingPathComponent(recording.fileName)
    }
}

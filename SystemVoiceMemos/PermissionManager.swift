//
//  PermissionManager.swift
//  SystemVoiceMemos
//
//  Created by aramb-dev on 01/13/26.
//

import Foundation
import AVFoundation
import ScreenCaptureKit

@MainActor
final class PermissionManager: ObservableObject {
    @Published var isAudioAuthorized = false
    @Published var isScreenRecordingAuthorized = false
    
    static let shared = PermissionManager()
    
    private init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        checkAudioPermission()
        checkScreenRecordingPermission()
    }
    
    func checkAudioPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        isAudioAuthorized = (status == .authorized)
    }
    
    func requestAudioPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        isAudioAuthorized = granted
    }
    
    func checkScreenRecordingPermission() {
        // CGPreflightScreenCaptureAccess() returns true if authorized
        isScreenRecordingAuthorized = CGPreflightScreenCaptureAccess()
    }
    
    func requestScreenRecordingPermission() {
        // CGRequestScreenCaptureAccess() triggers the system prompt
        // Note: It doesn't return a bool immediately in a way that's useful for 'await' 
        // because the user has to go to System Settings.
        _ = CGRequestScreenCaptureAccess()
    }
    
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

//
//  UpdaterManager.swift
//  SystemVoiceMemos
//
//  Manages automatic update checking using Sparkle framework.
//

import Foundation
import Sparkle

/// Manages automatic software updates via Sparkle
///
/// This class:
/// - Configures Sparkle updater on app launch
/// - Provides manual update check functionality
/// - Integrates with GitHub releases for update distribution
@MainActor
final class UpdaterManager: ObservableObject {
    
    // MARK: - Properties
    
    /// The Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController
    
    /// Whether the updater can check for updates
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize Sparkle with default configuration
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Manually check for updates
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    /// Get the updater for menu item binding
    var updater: SPUUpdater {
        updaterController.updater
    }
}

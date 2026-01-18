//
//  UpdaterManager.swift
//  SystemVoiceMemos
//
//  Manages automatic update checking using Sparkle framework.
//

import Foundation
import Sparkle
import Combine

/// Manages automatic software updates via Sparkle
///
/// This class:
/// - Configures Sparkle updater on app launch
/// - Provides manual update check functionality
/// - Integrates with GitHub releases for update distribution
/// - Responds to user settings for update intervals and automatic checks
@MainActor
final class UpdaterManager: ObservableObject {
    
    // MARK: - Properties
    
    /// The Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController
    
    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()
    
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
        
        // Apply initial settings
        applySettings()
        
        // Listen for settings changes
        setupSettingsObservers()
        
        // Listen for manual update check requests
        NotificationCenter.default.publisher(for: .checkForUpdates)
            .sink { [weak self] _ in
                self?.checkForUpdates()
            }
            .store(in: &cancellables)
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
    
    // MARK: - Private Methods
    
    /// Apply current settings to the updater
    private func applySettings() {
        let automaticChecks = UserDefaults.standard.bool(forKey: "automaticUpdateChecks")
        let interval = UserDefaults.standard.integer(forKey: "updateCheckInterval")
        
        // Default to enabled with daily checks if not set
        let shouldCheck = UserDefaults.standard.object(forKey: "automaticUpdateChecks") == nil ? true : automaticChecks
        let checkInterval = interval > 0 ? TimeInterval(interval) : 86400
        
        updaterController.updater.automaticallyChecksForUpdates = shouldCheck
        updaterController.updater.updateCheckInterval = checkInterval
    }
    
    /// Set up observers for settings changes
    private func setupSettingsObservers() {
        // Observe automatic checks toggle
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.applySettings()
            }
            .store(in: &cancellables)
    }
}

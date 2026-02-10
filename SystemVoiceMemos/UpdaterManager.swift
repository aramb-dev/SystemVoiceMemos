//
//  UpdaterManager.swift
//  SystemVoiceMemos
//
//  Manages automatic update checking using Sparkle framework.
//
//  NOTE: This file requires the Sparkle package to be added in Xcode.
//  Until then, it will function as a stub that does nothing.
//

import Foundation
import Combine

#if canImport(Sparkle)
import Sparkle
#endif

/// Manages automatic software updates via Sparkle
///
/// This class:
/// - Configures Sparkle updater on app launch
/// - Provides manual update check functionality
/// - Integrates with GitHub releases for update distribution
/// - Responds to user settings for update intervals and automatic checks
@MainActor
final class UpdaterManager: ObservableObject {
    
    #if canImport(Sparkle)
    // MARK: - Properties (Sparkle Available)
    
    /// The Sparkle updater controller
    private var updaterController: SPUStandardUpdaterController?

    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Reentrancy guard to prevent observer feedback loop
    private var isApplyingSettings = false
    
    /// Whether the updater can check for updates
    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }
    
    // MARK: - Initialization
    
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Apply initial settings
        applySettings()
        
        // Listen for settings changes
        setupSettingsObservers()
    }
    
    // MARK: - Public Methods
    
    /// Manually check for updates
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
    
    /// Get the updater for menu item binding
    var updater: SPUUpdater? {
        updaterController?.updater
    }
    
    // MARK: - Private Methods
    
    /// Apply current settings to the updater.
    /// Uses reentrancy guard because Sparkle writes to UserDefaults internally,
    /// which fires didChangeNotification, which would call this again.
    private func applySettings() {
        guard !isApplyingSettings else { return }
        isApplyingSettings = true
        defer { isApplyingSettings = false }

        guard let updater = updaterController?.updater else { return }

        let shouldCheck = UserDefaults.standard.object(forKey: "automaticUpdateChecks") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "automaticUpdateChecks")
        let interval = UserDefaults.standard.integer(forKey: "updateCheckInterval")
        let checkInterval = interval > 0 ? TimeInterval(interval) : 86400

        if updater.automaticallyChecksForUpdates != shouldCheck {
            updater.automaticallyChecksForUpdates = shouldCheck
        }
        if updater.updateCheckInterval != checkInterval {
            updater.updateCheckInterval = checkInterval
        }
    }
    
    /// Set up observers for settings changes
    private func setupSettingsObservers() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.applySettings()
            }
            .store(in: &cancellables)
    }
    
    #else
    // MARK: - Stub Implementation (Sparkle Not Available)
    
    var canCheckForUpdates: Bool { false }
    
    init() {
        print("⚠️ Sparkle framework not available. Add the Sparkle package dependency in Xcode.")
        print("   File → Add Package Dependencies → https://github.com/sparkle-project/Sparkle")
    }
    
    func checkForUpdates() {
        print("⚠️ Cannot check for updates: Sparkle framework not installed")
    }
    
    #endif
}

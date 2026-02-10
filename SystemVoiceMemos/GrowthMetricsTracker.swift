//
//  GrowthMetricsTracker.swift
//  SystemVoiceMemos
//
//  Lightweight local event counter for viral feature measurement.
//

import Foundation

enum GrowthMetricsTracker {
    enum Event {
        case shareClicked
        case shareCompleted
    }

    static func track(_ event: Event) {
        let defaults = UserDefaults.standard

        switch event {
        case .shareClicked:
            let count = defaults.integer(forKey: AppConstants.UserDefaultsKeys.shareClickedCount)
            defaults.set(count + 1, forKey: AppConstants.UserDefaultsKeys.shareClickedCount)
        case .shareCompleted:
            let count = defaults.integer(forKey: AppConstants.UserDefaultsKeys.shareCompletedCount)
            defaults.set(count + 1, forKey: AppConstants.UserDefaultsKeys.shareCompletedCount)
            defaults.set(Date(), forKey: AppConstants.UserDefaultsKeys.lastShareCompletedAt)
        }
    }
}

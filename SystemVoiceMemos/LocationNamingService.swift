//
//  LocationNamingService.swift
//  SystemVoiceMemos
//
//  Resolves the user's current city for location-based recording names.
//

import Foundation
import CoreLocation

@MainActor
final class LocationNamingService: NSObject {
    static let shared = LocationNamingService()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var continuation: CheckedContinuation<String?, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var isRequestingLocation = false

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Prompts for location authorization if not yet determined.
    func requestAuthorizationIfNeeded() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        let status = locationManager.authorizationStatus
        guard status == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    /// Resolves a city token suitable for recording names.
    ///
    /// Returns nil when permission is denied, location services are unavailable,
    /// or lookup times out.
    func cityToken(timeoutSeconds: TimeInterval = 6) async -> String? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }
        guard continuation == nil else { return nil }

        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            return nil
        }

        requestAuthorizationIfNeeded()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.startTimeout(seconds: timeoutSeconds)

            let latestStatus = self.locationManager.authorizationStatus
            if Self.isLocationAuthorized(latestStatus) {
                self.requestCurrentLocation()
            }
        }
    }

    private func startTimeout(seconds: TimeInterval) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            let duration = UInt64(max(seconds, 1) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: duration)
            await MainActor.run {
                self?.finish(with: nil)
            }
        }
    }

    private func requestCurrentLocation() {
        guard continuation != nil else { return }
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        locationManager.requestLocation()
    }

    private func resolveToken(from location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }

            let place = placemarks?.first
            let rawCity = place?.locality ?? place?.subAdministrativeArea ?? place?.administrativeArea
            let token = Self.sanitizeLocationToken(rawCity)
            Task { @MainActor in
                self.finish(with: token)
            }
        }
    }

    nonisolated private static func sanitizeLocationToken(_ input: String?) -> String? {
        guard let input = input, !input.isEmpty else { return nil }
        let compact = input.replacingOccurrences(of: " ", with: "")
        let sanitized = compact.filter { $0.isLetter || $0.isNumber }
        return sanitized.isEmpty ? nil : sanitized
    }

    nonisolated private static func isLocationAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return status == .authorizedAlways
        #else
        return status == .authorizedAlways || status == .authorizedWhenInUse
        #endif
    }

    private func finish(with token: String?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        isRequestingLocation = false

        continuation?.resume(returning: token)
        continuation = nil
    }
}

extension LocationNamingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if Self.isLocationAuthorized(status) {
                requestCurrentLocation()
            } else if status == .denied || status == .restricted {
                finish(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                finish(with: nil)
                return
            }
            resolveToken(from: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finish(with: nil)
        }
    }
}

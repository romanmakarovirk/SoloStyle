//
//  LocationManager.swift
//  SoloStyle
//
//  CoreLocation wrapper with async/await
//

import CoreLocation

@MainActor
@Observable
final class LocationManager: NSObject {
    static let shared = LocationManager()

    var latitude: Double = 52.2978   // Irkutsk default (change to your city)
    var longitude: Double = 104.2964
    var isAuthorized = false
    var errorMessage: String?

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        Task { @MainActor in
            #if !targetEnvironment(simulator)
            self.latitude = lat
            self.longitude = lon
            #else
            // On simulator, only update if not default Apple HQ location
            let isAppleHQ = abs(lat - 37.7858) < 0.01 && abs(lon - (-122.4064)) < 0.01
            if !isAppleHQ {
                self.latitude = lat
                self.longitude = lon
            }
            #endif
            // Stop GPS after getting a valid location to save battery
            self.stopUpdating()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isAuthorized = true
                self.errorMessage = nil
                self.startUpdating()
            case .denied, .restricted:
                self.isAuthorized = false
                self.errorMessage = "Разрешите доступ к геолокации в настройках"
            case .notDetermined:
                self.isAuthorized = false
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "Не удалось определить местоположение"
        }
    }
}

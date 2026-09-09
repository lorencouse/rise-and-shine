import Foundation
import CoreLocation
import MapKit
import RiseCore

/// One-shot device location plus place search. No continuous tracking.
@Observable
final class LocationService {

    enum LocationError: LocalizedError {
        case denied, unavailable

        var errorDescription: String? {
            switch self {
            case .denied: "Location access is off. Enable it in Settings or pick a city manually."
            case .unavailable: "Couldn't determine your location. Try again or pick a city manually."
            }
        }
    }

    private(set) var isLocating = false

    /// Requests permission if needed and returns a single fix with a friendly name.
    func currentLocation() async throws -> SavedLocation {
        isLocating = true
        defer { isLocating = false }

        var fix: CLLocation?
        for try await update in CLLocationUpdate.liveUpdates(.otherNavigation) {
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                throw LocationError.denied
            }
            if let location = update.location {
                fix = location
                break
            }
            if update.authorizationRequestInProgress { continue }
            if update.locationUnavailable { throw LocationError.unavailable }
        }
        guard let fix else { throw LocationError.unavailable }

        let name = await placeName(for: fix)
        return SavedLocation(name: name,
                             latitude: fix.coordinate.latitude,
                             longitude: fix.coordinate.longitude,
                             followsDevice: true)
    }

    /// Reverse-geocodes to "City" or "City, Region". Falls back to coordinates.
    func placeName(for location: CLLocation) async -> String {
        let fallback = Formatters.coordinate(location.coordinate.latitude, location.coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return fallback }
        do {
            let items = try await request.mapItems
            if let address = items.first?.addressRepresentations {
                return address.cityWithContext ?? address.regionName ?? fallback
            }
        } catch {
            // ignore and fall back
        }
        return fallback
    }

    /// Free-text place search, e.g. "Lisbon".
    func search(_ query: String) async -> [SavedLocation] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address]
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(8).map { item in
                let coordinate = item.location.coordinate
                let name = item.addressRepresentations?.cityWithContext ?? item.name ?? trimmed
                return SavedLocation(name: name,
                                     latitude: coordinate.latitude,
                                     longitude: coordinate.longitude,
                                     followsDevice: false)
            }
        } catch {
            return []
        }
    }
}

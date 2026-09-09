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

        let place = await describe(fix)
        return SavedLocation(name: place.name,
                             latitude: fix.coordinate.latitude,
                             longitude: fix.coordinate.longitude,
                             followsDevice: true,
                             timeZoneIdentifier: place.timeZoneIdentifier)
    }

    /// Reverse-geocodes to "City" or "City, Region". Falls back to coordinates.
    func placeName(for location: CLLocation) async -> String {
        await describe(location).name
    }

    /// Reverse-geocodes once for both the display name and the place's time zone, so a
    /// location picked here already knows which zone its sunrises belong to.
    private func describe(_ location: CLLocation) async -> (name: String, timeZoneIdentifier: String?) {
        let fallback = Formatters.coordinate(location.coordinate.latitude, location.coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return (fallback, nil) }
        do {
            let items = try await request.mapItems
            guard let item = items.first else { return (fallback, nil) }
            let name = item.addressRepresentations?.cityWithContext
                ?? item.addressRepresentations?.regionName
                ?? fallback
            return (name, item.timeZone?.identifier)
        } catch {
            return (fallback, nil)
        }
    }

    /// The zone for a saved coordinate. Used to backfill locations stored before
    /// `timeZoneIdentifier` existed, so upgrading users get local times too.
    func timeZoneIdentifier(latitude: Double, longitude: Double) async -> String? {
        await describe(CLLocation(latitude: latitude, longitude: longitude)).timeZoneIdentifier
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
                                     followsDevice: false,
                                     timeZoneIdentifier: item.timeZone?.identifier)
            }
        } catch {
            return []
        }
    }
}

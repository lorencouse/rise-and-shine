import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var geocodeCache: [String: String] = [:] // Cache for storing city names
    private var lastGeocodeRequestTime: Date?

    @Published var locationStatus: CLAuthorizationStatus?
    @Published var currentLocation: CLLocation?
    @Published var cityName: String?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        // Removed automatic start of location updates.
    }
    
    // This method is now responsible for triggering location updates.
    func requestSingleLocationUpdate() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.requestLocation() // Request a single location update
            }
        } else {
            locationManager.requestWhenInUseAuthorization() // Request permission if not already authorized
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationStatus = status
        // Now, only updates the locationStatus without starting location updates.
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation = location
        
        reverseGeocodeLocation(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    private func canPerformGeocodeRequest() -> Bool {
        guard let lastRequestTime = lastGeocodeRequestTime else {
            return true
        }
        let timeIntervalSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        return timeIntervalSinceLastRequest > 60
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        let coordinateKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        
        if let cachedCityName = geocodeCache[coordinateKey] {
            self.cityName = cachedCityName
            return
        }
        
        guard canPerformGeocodeRequest() else {
            print("Geocode request skipped due to rate limiting.")
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let error = error {
                print("Reverse geocoding failed with error: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                let cityName = placemark.locality ?? "Unknown City"
                self.cityName = cityName
                self.geocodeCache[coordinateKey] = cityName
                self.lastGeocodeRequestTime = Date()
            }
        }
    }
}

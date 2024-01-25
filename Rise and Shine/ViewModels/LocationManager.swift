import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public var locationManager = CLLocationManager()

    @Published var locationStatus: CLAuthorizationStatus?
    @Published var currentLocation: CLLocation?
    @Published var cityName: String?

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationStatus = status
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation = location
        UserDefaults.standard.currentLatitude = location.coordinate.latitude
        UserDefaults.standard.currentLongitude = location.coordinate.latitude
        

        // Use reverse geocoding to get city name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                print("Reverse geocoding failed with error: \(error.localizedDescription)")
                return
            }

            if let placemark = placemarks?.first {

                self.cityName = placemark.locality ?? "Unknown City"
                UserDefaults.standard.currentCity = self.cityName ?? "Unknown City"
                print(UserDefaults.standard.currentCity)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

func fetchLocation(locationManager: LocationManager) -> String {
    guard let status = locationManager.locationStatus else {
        return "Unknown Location Access Status"
    }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
        if locationManager.currentLocation != nil {
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.latitude, forKey: "currentLatitude")
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.longitude, forKey: "currentLongitude")
            UserDefaults.standard.setValue( locationManager.cityName, forKey: "currentCity")
            return locationManager.cityName ?? "Unknown City"
        } else {
            return "Location not available"
        }
    case .denied, .restricted:
        return "Location Access Denied"
    case .notDetermined:
        return "Location Access Not Determined"
    @unknown default:
        return "Error fetching location"
    }
}

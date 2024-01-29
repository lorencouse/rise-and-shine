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

            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

func fetchLocation(locationManager: LocationManager) {
    guard let status = locationManager.locationStatus else {
        print("Unknown Location Access Status")
        return
    }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
        if locationManager.currentLocation != nil {
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.latitude, forKey: "currentLatitude")
            UserDefaults.standard.setValue( locationManager.currentLocation?.coordinate.longitude, forKey: "currentLongitude")
            UserDefaults.standard.setValue( locationManager.cityName, forKey: "currentCity")
           
        } else {
            UserDefaults.standard.setValue( "Could Not Fetch Location", forKey: "currentCity")
            print("Location not available")
            return
        }
    case .denied, .restricted:
        print("Location Access Denied")
        return
    case .notDetermined:
        print("Location Access Not Determined")
        return
    @unknown default:
        print("Error fetching location")
        return
    }
}



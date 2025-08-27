
import Foundation
import CoreLocation

class LocationNameCache {
    static let shared = LocationNameCache()

    private var cache = [CLLocation: String]()
    private let geocoder = CLGeocoder()

    private init() {}

    func locationName(for location: CLLocation, completion: @escaping (String) -> Void) {
        if let cachedName = cache[location] {
            completion(cachedName)
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            if let placemark = placemarks?.first {
                var components = [String]()
                if let name = placemark.name {
                    components.append(name)
                }
                if let locality = placemark.locality {
                    components.append(locality)
                }
                if let administrativeArea = placemark.administrativeArea {
                    components.append(administrativeArea)
                }

                let name = components.joined(separator: ", ")
                self?.cache[location] = name
                completion(name)
            } else {
                completion("Unknown Location")
            }
        }
    }
}

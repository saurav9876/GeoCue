import Foundation
import CoreLocation

class LocationNameCache {
    static let shared = LocationNameCache()

    private var cache = [String: String]()
    private let geocoder = CLGeocoder()
    private var pendingRequests = Set<String>()

    private init() {}
    
    // Generate a cache key from coordinates (rounded to avoid tiny differences)
    private func cacheKey(for location: CLLocation) -> String {
        let lat = (location.coordinate.latitude * 10000).rounded() / 10000
        let lon = (location.coordinate.longitude * 10000).rounded() / 10000
        return "\(lat),\(lon)"
    }

    func locationName(for location: CLLocation, completion: @escaping (String) -> Void) {
        let key = cacheKey(for: location)
        
        // Check cache first
        if let cachedName = cache[key] {
            completion(cachedName)
            return
        }
        
        // Check if we're already processing this location
        if pendingRequests.contains(key) {
            // Wait a bit and try cache again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if let cachedName = self?.cache[key] {
                    completion(cachedName)
                } else {
                    completion("Loading location...")
                }
            }
            return
        }
        
        // Mark as pending and start geocoding
        pendingRequests.insert(key)

        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            DispatchQueue.main.async {
                self?.pendingRequests.remove(key)
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    let fallbackName = self?.generateFallbackName(for: location) ?? "Unknown Location"
                    self?.cache[key] = fallbackName
                    completion(fallbackName)
                    return
                }
                
                if let placemark = placemarks?.first {
                    let name = self?.formatPlacemarkName(placemark) ?? "Unknown Location"
                    self?.cache[key] = name
                    completion(name)
                } else {
                    let fallbackName = self?.generateFallbackName(for: location) ?? "Unknown Location"
                    self?.cache[key] = fallbackName
                    completion(fallbackName)
                }
            }
        }
    }
    
    private func formatPlacemarkName(_ placemark: CLPlacemark) -> String {
        var components = [String]()
        
        // Priority: name > thoroughfare + subThoroughfare > locality
        if let name = placemark.name, !name.isEmpty {
            components.append(name)
        } else if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        } else if let locality = placemark.locality {
            components.append(locality)
        }
        
        // Add locality if we don't have it yet and it's different from name
        if let locality = placemark.locality, 
           !components.isEmpty && !components[0].contains(locality) {
            components.append(locality)
        }
        
        return components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
    }
    
    private func generateFallbackName(for location: CLLocation) -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return String(format: "%.4f, %.4f", lat, lon)
    }
}
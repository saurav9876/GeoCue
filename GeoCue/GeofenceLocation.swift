import Foundation
import CoreLocation

struct GeofenceLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var entryMessage: String
    var exitMessage: String
    var notifyOnEntry: Bool
    var notifyOnExit: Bool
    var isEnabled: Bool
    var notificationMode: NotificationMode
    let dateCreated: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        address: String = "",
        latitude: Double,
        longitude: Double,
        radius: Double = 100.0,
        entryMessage: String = "",
        exitMessage: String = "",
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = false,
        isEnabled: Bool = true,
        notificationMode: NotificationMode = .normal,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.entryMessage = entryMessage
        self.exitMessage = exitMessage
        self.notifyOnEntry = notifyOnEntry
        self.notifyOnExit = notifyOnExit
        self.isEnabled = isEnabled
        self.notificationMode = notificationMode
        self.dateCreated = dateCreated
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    static func == (lhs: GeofenceLocation, rhs: GeofenceLocation) -> Bool {
        lhs.id == rhs.id
    }
}
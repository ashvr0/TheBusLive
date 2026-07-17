import Foundation
import CoreLocation

/// A single vehicle's live position, matching the `vehicle` element
/// returned by `http://api.thebus.org/vehicle/`.
struct Vehicle: Identifiable, Codable, Hashable {
    let number: String
    let trip: String?
    let driver: String?
    let latitude: Double
    let longitude: Double
    let adherence: String?
    let lastMessage: String?
    let routeShortName: String?
    let headsign: String?

    var id: String { number }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case number, trip, driver, latitude, longitude, adherence
        case lastMessage = "last_message"
        case routeShortName = "route_short_name"
        case headsign
    }

    /// Positive adherence means early, negative means late, per TheBus docs.
    var adherenceMinutes: Int? {
        guard let adherence, let value = Int(adherence) else { return nil }
        return value
    }
}

/// Wrapper matching the top level `vehicles` element.
struct VehiclesResponse: Codable {
    let timestamp: String?
    let errorMessage: String?
    let vehicle: [Vehicle]?
}

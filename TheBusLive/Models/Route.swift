import Foundation

/// Represents a single TheBus route entry, matching the `route`
/// element returned by `http://api.thebus.org/route/`.
struct BusRoute: Identifiable, Codable, Hashable {
    let routeNum: String
    let shapeID: String?
    let firstStop: String?
    let headsign: String?

    var id: String { "\(routeNum)-\(headsign ?? "")-\(shapeID ?? "")" }

    init(routeNum: String, shapeID: String? = nil, firstStop: String? = nil, headsign: String? = nil) {
        self.routeNum = routeNum
        self.shapeID = shapeID
        self.firstStop = firstStop
        self.headsign = headsign
    }
}

/// Wrapper matching the top level `routes` element, including the
/// optional error message TheBus returns inline rather than as an
/// HTTP error code.
struct RouteResponse: Codable {
    let routeName: String?
    let routeID: String?
    let errorMessage: String?
    let route: [BusRoute]
}

extension BusRoute {
    /// Full list of TheBus routes, loaded once from the bundled
    /// `routes.json` (generated from GTFS `routes.txt` by
    /// `Scripts/generate_stops_json.py`'s sibling script). Used so
    /// route search/browse works without a live network call; live
    /// arrivals/shape lookups still hit the API as needed.
    static let allRoutes: [BusRoute] = {
        guard
            let url = Bundle.main.url(forResource: "routes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([BusRoute].self, from: data),
            !decoded.isEmpty
        else {
            return []
        }
        return decoded
    }()
}

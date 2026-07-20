import Foundation

/// Networking client for TheBus's Web API.
///
/// TheBus's API returns XML rather than JSON, so this client uses
/// `XMLParser` to build a generic node tree, then maps that tree onto the
/// app's Codable models. This avoids any third party dependency.
///
/// Features:
/// - Request deduplication for arrivals, vehicles, and routes
/// - 30-second arrivals cache to reduce API calls
/// - Detailed error messages that guide users to solutions
/// - Structured logging for debugging
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    
    // MARK: - Cache structures
    private var arrivalsCache: [String: (data: ArrivalsResponse, timestamp: Date)] = [:]
    private var vehicleCache: [String: (data: VehiclesResponse, timestamp: Date)] = [:]
    private var routeCache: [String: (data: RouteResponse, timestamp: Date)] = [:]
    
    private let cacheExpirationSeconds: TimeInterval = 30

    // MARK: - In-flight request tracking
    private var inFlightRequests: [String: Task<Any, Error>] = [:]
    nonisolated(unsafe) private let cacheLock = NSLock()
    nonisolated(unsafe) private let requestLock = NSLock()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public requests

    func fetchArrivals(stopID: String) async throws -> ArrivalsResponse {
        let cacheKey = "arrivals:\(stopID)"
        return try await fetchWithDeduplication(
            cacheKey: cacheKey,
            cachedValue: getCachedArrivals(stopID: stopID),
            fetch: {
                let node = try await self.fetchXML(.arrivals(stopID: stopID))
                let response = try ArrivalsXMLMapper.map(node)
                self.setCachedArrivals(response, for: stopID)
                return response
            }
        )
    }

    func fetchVehicle(number: String) async throws -> VehiclesResponse {
        let cacheKey = "vehicle:\(number)"
        return try await fetchWithDeduplication(
            cacheKey: cacheKey,
            cachedValue: getCachedVehicle(number: number),
            fetch: {
                let node = try await self.fetchXML(.vehicle(number: number))
                let response = try VehicleXMLMapper.map(node)
                self.setCachedVehicle(response, for: number)
                return response
            }
        )
    }

    func fetchRoutes(routeNum: String) async throws -> RouteResponse {
        let cacheKey = "route:\(routeNum)"
        return try await fetchWithDeduplication(
            cacheKey: cacheKey,
            cachedValue: getCachedRoute(routeNum: routeNum),
            fetch: {
                let node = try await self.fetchXML(.routeByNumber(routeNum: routeNum))
                let response = try RouteXMLMapper.map(node)
                self.setCachedRoute(response, for: routeNum)
                return response
            }
        )
    }

    func searchRoutes(headsign: String) async throws -> RouteResponse {
        let cacheKey = "route:headsign:\(headsign)"
        return try await fetchWithDeduplication(
            cacheKey: cacheKey,
            cachedValue: nil,
            fetch: {
                let node = try await self.fetchXML(.routeByHeadsign(text: headsign))
                return try RouteXMLMapper.map(node)
            }
        )
    }

    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        arrivalsCache.removeAll()
        vehicleCache.removeAll()
        routeCache.removeAll()
    }

    // MARK: - Core fetch with XML parsing

    private func fetchXML(_ endpoint: Endpoint) async throws -> XMLNode {
        guard APIConfig.hasKey else {
            throw APIError.missingAPIKey
        }
        guard let url = endpoint.url() else {
            throw APIError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch {
            throw APIError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 400:
            debugLog("HTTP 400 Bad Request - invalid stop ID or route number")
            throw APIError.httpStatus(400, "Invalid request. Check your stop number or route.")
        case 401, 403:
            debugLog("HTTP 403 Unauthorized - API key is invalid or expired")
            throw APIError.httpStatus(403, "API key is invalid or expired. Update it in Settings.")
        case 404:
            debugLog("HTTP 404 Not Found - stop or route doesn't exist")
            throw APIError.httpStatus(404, "Stop or route not found.")
        case 429:
            debugLog("HTTP 429 Rate Limited - too many requests")
            throw APIError.httpStatus(429, "Too many requests. Please try again in a moment.")
        case 500..<600:
            debugLog("HTTP \(httpResponse.statusCode) Server Error")
            throw APIError.httpStatus(httpResponse.statusCode, "TheBus API is temporarily unavailable. Please try again.")
        default:
            debugLog("HTTP \(httpResponse.statusCode) Unexpected Status")
            throw APIError.httpStatus(httpResponse.statusCode, "An unexpected error occurred.")
        }

        guard !data.isEmpty else {
            throw APIError.noData
        }

        do {
            return try SimpleXMLParser.parse(data: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    // MARK: - Request deduplication

    private func fetchWithDeduplication<T>(
        cacheKey: String,
        cachedValue: T?,
        fetch: @escaping () async throws -> T
    ) async throws -> T {
        if let cached = cachedValue {
            return cached
        }

        if let existingTask = getInFlightRequest(key: cacheKey) as? Task<T, Error> {
            return try await existingTask.value
        }

        let task: Task<T, Error> = Task {
            try await fetch()
        }

        storeInFlightRequest(key: cacheKey, task: task)
        defer { removeInFlightRequest(key: cacheKey) }

        return try await task.value
    }

    // MARK: - Cache management

    private func getCachedArrivals(stopID: String) -> ArrivalsResponse? {
        getCached(from: &arrivalsCache, key: stopID)
    }

    private func setCachedArrivals(_ response: ArrivalsResponse, for stopID: String) {
        setCached(in: &arrivalsCache, value: response, key: stopID)
    }

    private func getCachedVehicle(number: String) -> VehiclesResponse? {
        getCached(from: &vehicleCache, key: number)
    }

    private func setCachedVehicle(_ response: VehiclesResponse, for number: String) {
        setCached(in: &vehicleCache, value: response, key: number)
    }

    private func getCachedRoute(routeNum: String) -> RouteResponse? {
        getCached(from: &routeCache, key: routeNum)
    }

    private func setCachedRoute(_ response: RouteResponse, for routeNum: String) {
        setCached(in: &routeCache, value: response, key: routeNum)
    }

    private func getCached<T>(from cache: inout [String: (data: T, timestamp: Date)], key: String) -> T? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = cache[key] else { return nil }

        let elapsed = Date().timeIntervalSince(cached.timestamp)
        guard elapsed < cacheExpirationSeconds else {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.data
    }

    private func setCached<T>(in cache: inout [String: (data: T, timestamp: Date)], value: T, key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[key] = (value, Date())
    }

    // MARK: - In-flight request tracking

    private func getInFlightRequest(key: String) -> Task<Any, Error>? {
        requestLock.lock()
        defer { requestLock.unlock() }
        return inFlightRequests[key]
    }

    private func storeInFlightRequest<T>(key: String, task: Task<T, Error>) {
        requestLock.lock()
        defer { requestLock.unlock() }
        inFlightRequests[key] = task
    }

    private func removeInFlightRequest(key: String) {
        requestLock.lock()
        defer { requestLock.unlock() }
        inFlightRequests.removeValue(forKey: key)
    }

    // MARK: - Debugging

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("[APIClient] \(message)")
        #endif
    }
}

// MARK: - Minimal XML tree

final class XMLNode {
    let name: String
    var text: String = ""
    var children: [XMLNode] = []
    weak var parent: XMLNode?

    init(name: String, parent: XMLNode? = nil) {
        self.name = name
        self.parent = parent
    }

    func firstChild(_ name: String) -> XMLNode? {
        children.first { $0.name == name }
    }

    func allChildren(_ name: String) -> [XMLNode] {
        children.filter { $0.name == name }
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - XML parser

enum SimpleXMLParser {
    static func parse(data: Data) throws -> XMLNode {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        let success = parser.parse()

        guard let root = delegate.root else {
            if let parserError = parser.parserError {
                throw APIError.decodingFailed(parserError)
            } else if !success {
                let parseError = NSError(
                    domain: "SimpleXMLParser",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "XML parsing failed"]
                )
                throw APIError.decodingFailed(parseError)
            } else {
                throw APIError.invalidResponse
            }
        }

        return root
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var root: XMLNode?
        private var stack: [XMLNode] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let node = XMLNode(name: elementName, parent: stack.last)
            stack.last?.children.append(node)
            stack.append(node)
            if root == nil {
                root = node
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            stack.removeLast()
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            #if DEBUG
            NSLog("[XMLParser] Parse error: \(parseError)")
            #endif
        }
    }
}

// MARK: - XML Mappers

enum ArrivalsXMLMapper {
    static func map(_ root: XMLNode) throws -> ArrivalsResponse {
        let stop = root.firstChild("stop")?.trimmedText
        let timestamp = root.firstChild("timestamp")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText

        let arrivals: [Arrival] = root.allChildren("arrival").compactMap { node in
            guard let route = node.firstChild("route")?.trimmedText, !route.isEmpty else {
                return nil
            }
            guard let id = node.firstChild("id")?.trimmedText, !id.isEmpty else {
                return nil
            }
            guard let stopTime = node.firstChild("stopTime")?.trimmedText, !stopTime.isEmpty else {
                return nil
            }

            return Arrival(
                id: id,
                trip: node.firstChild("trip")?.trimmedText,
                route: route,
                headsign: node.firstChild("headsign")?.trimmedText ?? "",
                vehicle: node.firstChild("vehicle")?.trimmedText,
                direction: node.firstChild("direction")?.trimmedText,
                stopTime: stopTime,
                date: node.firstChild("date")?.trimmedText,
                estimated: (node.firstChild("estimated")?.trimmedText == "1"),
                longitude: Double(node.firstChild("longitude")?.trimmedText ?? ""),
                latitude: Double(node.firstChild("latitude")?.trimmedText ?? ""),
                shape: node.firstChild("shape")?.trimmedText,
                canceled: Int(node.firstChild("canceled")?.trimmedText ?? "")
            )
        }

        return ArrivalsResponse(
            stop: stop,
            timestamp: timestamp,
            errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil,
            arrival: arrivals
        )
    }
}

enum VehicleXMLMapper {
    static func map(_ root: XMLNode) throws -> VehiclesResponse {
        let timestamp = root.firstChild("timestamp")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText

        let vehicles: [Vehicle] = root.allChildren("vehicle").compactMap { node in
            guard
                let lat = Double(node.firstChild("latitude")?.trimmedText ?? ""),
                let lon = Double(node.firstChild("longitude")?.trimmedText ?? "")
            else {
                return nil
            }

            guard let number = node.firstChild("number")?.trimmedText, !number.isEmpty else {
                return nil
            }

            return Vehicle(
                number: number,
                trip: node.firstChild("trip")?.trimmedText,
                driver: node.firstChild("driver")?.trimmedText,
                latitude: lat,
                longitude: lon,
                adherence: node.firstChild("adherence")?.trimmedText,
                lastMessage: node.firstChild("last_message")?.trimmedText,
                routeShortName: node.firstChild("route_short_name")?.trimmedText,
                headsign: node.firstChild("headsign")?.trimmedText
            )
        }

        return VehiclesResponse(
            timestamp: timestamp,
            errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil,
            vehicle: vehicles
        )
    }
}

enum RouteXMLMapper {
    static func map(_ root: XMLNode) throws -> RouteResponse {
        let routeName = root.firstChild("routeName")?.trimmedText
        let routeID = root.firstChild("routeID")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText

        let routes: [BusRoute] = root.allChildren("route").compactMap { node in
            guard let routeNum = node.firstChild("routeNum")?.trimmedText, !routeNum.isEmpty else {
                return nil
            }

            return BusRoute(
                routeNum: routeNum,
                shapeID: node.firstChild("shapeID")?.trimmedText,
                firstStop: node.firstChild("firstStop")?.trimmedText,
                headsign: node.firstChild("headsign")?.trimmedText
            )
        }

        return RouteResponse(
            routeName: routeName,
            routeID: routeID,
            errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil,
            route: routes
        )
    }
}
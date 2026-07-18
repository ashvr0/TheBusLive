import Foundation

/// A single predicted or scheduled arrival, matching the `arrival`
/// element returned by `http://api.thebus.org/arrivals/`.
struct Arrival: Identifiable, Codable, Hashable {
    let id: String
    let trip: String?
    let route: String
    let headsign: String
    let vehicle: String?
    let direction: String?
    let stopTime: String
    let date: String?
    let estimated: Bool
    let longitude: Double?
    let latitude: Double?
    let shape: String?
    let canceled: Int?

    enum CodingKeys: String, CodingKey {
        case id, trip, route, headsign, vehicle, direction
        case stopTime = "stopTime"
        case date = "Date"
        case estimated, longitude, latitude, shape, canceled
    }

    var isCanceled: Bool {
        canceled == 1
    }

    /// Parses `stopTime` (and `date`, when present) into a `Date` for
    /// display and sorting. TheBus returns local Honolulu time strings.
    var arrivalDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Pacific/Honolulu")

        // Attempt to parse with date if available
        if let date, !date.isEmpty {
            formatter.dateFormat = "MM/dd/yyyy h:mm a"
            let combinedString = "\(date) \(stopTime)"
            if let parsed = formatter.date(from: combinedString) {
                return parsed
            } else {
                NSLog("Warning: Failed to parse arrival date '\(combinedString)' for arrival \(id) on route \(route)")
                // Continue to try parsing time-only below
            }
        }

        // Attempt to parse time-only
        formatter.dateFormat = "h:mm a"
        if let parsed = formatter.date(from: stopTime) {
            return parsed
        } else {
            NSLog("Warning: Failed to parse arrival time '\(stopTime)' for arrival \(id) on route \(route)")
            return nil
        }
    }
    
    /// Returns a human-readable representation of arrival time.
    /// This is useful for display when date parsing fails.
    var displayTime: String {
        // Return the raw stop time if available
        if !stopTime.isEmpty {
            return stopTime
        }
        return "Unknown"
    }
    
    /// Returns a human-readable description of arrival status.
    var statusDescription: String {
        if isCanceled {
            return "Cancelled"
        } else if estimated {
            return "Live"
        } else {
            return "Scheduled"
        }
    }
}

/// Wrapper matching the top level `stopTimes` element.
struct ArrivalsResponse: Codable {
    let stop: String?
    let timestamp: String?
    let errorMessage: String?
    let arrival: [Arrival]?
    
    /// Convenience property to check if the response indicates an error
    var hasError: Bool {
        errorMessage?.isEmpty == false
    }
    
    /// Convenience property to check if arrivals are available
    var hasArrivals: Bool {
        let arrivals = arrival ?? []
        return !arrivals.isEmpty
    }
}

// MARK: - Date Parsing Utilities
enum DateParsingUtility {
    /// Parses TheBus date/time strings with detailed error reporting
    /// Use this when you need to handle dates outside of the Arrival model
    static func parseTheBusDateTime(
        date: String?,
        time: String?,
        timezone: TimeZone = TimeZone(identifier: "Pacific/Honolulu") ?? .current
    ) -> Date? {
        guard let time = time, !time.isEmpty else {
            NSLog("Warning: Attempting to parse date/time with empty time component")
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        
        // Try full date + time
        if let date = date, !date.isEmpty {
            formatter.dateFormat = "MM/dd/yyyy h:mm a"
            let combined = "\(date) \(time)"
            if let parsed = formatter.date(from: combined) {
                return parsed
            } else {
                NSLog("Debug: Failed to parse combined date '\(combined)' with format 'MM/dd/yyyy h:mm a'")
            }
        }
        
        // Try time only
        formatter.dateFormat = "h:mm a"
        if let parsed = formatter.date(from: time) {
            return parsed
        } else {
            NSLog("Debug: Failed to parse time '\(time)' with format 'h:mm a'")
            return nil
        }
    }
    
    /// Formats a Date into TheBus-compatible string (for testing/comparison)
    static func formatAsTheBusTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Pacific/Honolulu") ?? .current
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    /// Formats a Date into TheBus-compatible date+time string (for testing)
    static func formatAsTheBusDateTime(_ date: Date) -> (date: String, time: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Pacific/Honolulu") ?? .current
        
        formatter.dateFormat = "MM/dd/yyyy"
        let dateStr = formatter.string(from: date)
        
        formatter.dateFormat = "h:mm a"
        let timeStr = formatter.string(from: date)
        
        return (dateStr, timeStr)
    }
}

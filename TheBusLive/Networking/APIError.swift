import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(Error)
    case serverMessage(String)
    case missingAPIKey
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build a valid request URL."
        case .requestFailed(let error):
            return "The network request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .httpStatus(let code):
            return "The server returned status code \(code)."
        case .decodingFailed(let error):
            return "Could not read the server's response: \(error.localizedDescription)"
        case .serverMessage(let message):
            return message
        case .missingAPIKey:
            return "API key not detected. An API key is required for this app to work — add yours in Settings."
        case .noData:
            return "No data was returned for this request."
        }
    }

    /// True when this error wraps a cancelled network request (e.g. the
    /// view disappeared mid-fetch, or a newer refresh superseded this
    /// one). Callers should generally treat this as "ignore" rather than
    /// showing it to the user as a failure.
    var isCancellation: Bool {
        if case .requestFailed(let underlying) = self,
           let urlError = underlying as? URLError,
           urlError.code == .cancelled {
            return true
        }
        return false
    }
}
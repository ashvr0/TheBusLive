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
            return "No TheBus API key is configured. Add your key in APIConfig.swift."
        case .noData:
            return "No data was returned for this request."
        }
    }
}

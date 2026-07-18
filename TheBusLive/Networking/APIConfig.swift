import Foundation

/// Central place for TheBus API configuration.
enum APIConfig {
    /// Fallback/default TheBus API application id (AppID), used only if
    /// the user hasn't entered their own key in Settings.
    private static let defaultKey = "3D6DF239-6FE0-4FDE-A88D-CA6D0A7881FB"

    /// The active API key: the user's key from Settings if they've set
    /// one, otherwise `defaultKey`.
    static var key: String {
        let stored = UserDefaults.standard.string(forKey: AppPreferenceKeys.apiKey) ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultKey : trimmed
    }

    static let scheme = "https"
    static let host = "api.thebus.org"

    /// TheBus's Terms of Use require this attribution to be shown
    /// wherever route or arrival data appears in the app.
    static let attributionText = "Route and arrival data provided by permission of Oahu Transit Services, Inc."
}
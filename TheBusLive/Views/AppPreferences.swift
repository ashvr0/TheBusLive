import SwiftUI
import MapKit

/// A curated set of accent colors the user can pick from in Settings.
/// Stored as a raw string so it round-trips cleanly through
/// `@AppStorage`.
enum AppAccentColor: String, CaseIterable, Identifiable {
    case blue
    case orange
    case green
    case purple
    case red
    case teal
    case pink
    case yellow

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .orange: return .orange
        case .green: return .green
        case .purple: return .purple
        case .red: return .red
        case .teal: return .teal
        case .pink: return .pink
        case .yellow: return .yellow
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

/// The map rendering style the user prefers across all map screens
/// (Home preview, All Stops, and the live vehicle map).
enum AppMapStyleOption: String, CaseIterable, Identifiable {
    case standard
    case satellite
    case hybrid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard: return .standard
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        }
    }
}

/// Central place for the `@AppStorage` keys used for user-facing
/// preferences, so every screen reads/writes the same keys.
enum AppPreferenceKeys {
    static let accentColor = "com.thebuslive.accentColor"
    static let mapStyle = "com.thebuslive.mapStyle"
}
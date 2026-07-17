import SwiftUI

struct ContentView: View {

    @AppStorage("com.thebuslive.preferredColorScheme") private var preferredColorSchemeRaw: String = "system"
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRaw: String = AppAccentColor.blue.rawValue

    private var preferredColorScheme: ColorScheme? {
        switch preferredColorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .blue).color
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "bus.fill")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(accentColor)
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesManager())
}
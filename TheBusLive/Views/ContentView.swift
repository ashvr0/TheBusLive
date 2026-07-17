import SwiftUI

struct ContentView: View {

    @AppStorage("com.thebuslive.preferredColorScheme") private var preferredColorSchemeRaw: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch preferredColorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
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
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView()
        .environmentObject(FavoritesManager())
}

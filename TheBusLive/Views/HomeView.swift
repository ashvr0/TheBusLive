import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager

    var body: some View {
        NavigationStack {
            List {
                if !favoritesManager.favorites.isEmpty {
                    Section("Favorite stops") {
                        ForEach(favoritesManager.favorites) { stop in
                            NavigationLink(value: stop) {
                                StopRow(stop: stop)
                            }
                        }
                    }
                }

                if !favoritesManager.recents.isEmpty {
                    Section("Recently viewed") {
                        ForEach(favoritesManager.recents) { stop in
                            NavigationLink(value: stop) {
                                StopRow(stop: stop)
                            }
                        }
                    }
                }

                if favoritesManager.favorites.isEmpty && favoritesManager.recents.isEmpty {
                    Section {
                        StatusView(kind: .empty(
                            title: "No stops yet",
                            message: "Search for a stop to see live arrivals, or add stops to your favorites.",
                            systemImage: "bus.fill"
                        ))
                        .listRowSeparator(.hidden)
                        .frame(minHeight: 260)
                    }
                }

                Section {
                    Text(APIConfig.attributionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("TheBus Live")
            .navigationDestination(for: Stop.self) { stop in
                StopDetailView(stop: stop)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(FavoritesManager())
}

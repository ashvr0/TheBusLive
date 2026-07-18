import SwiftUI

struct StopDetailView: View {

    let stop: Stop

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @StateObject private var viewModel: StopViewModel

    init(stop: Stop) {
        self.stop = stop
        _viewModel = StateObject(wrappedValue: StopViewModel(stop: stop))
    }

    /// The stop number line, always shown ("Stop 169").
    private var stopSubtitle: String {
        "Stop \(stop.stopID)"
    }

    /// "Last refresh: h:mm a" line, shown once arrivals have loaded at
    /// least once. Uses the device's current locale so the time renders
    /// in whatever 12h/24h format the user's system is set to, rather
    /// than a hardcoded format. Returns nil before the first successful
    /// load, so the toolbar only shows the stop number until then.
    private var refreshSubtitle: String? {
        guard let lastRefreshed = viewModel.lastRefreshed else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return "Last refresh: \(formatter.string(from: lastRefreshed))"
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                StatusView(kind: .loading)
            case .empty:
                StatusView(kind: .empty(
                    title: "No arrivals right now",
                    message: "There are no buses currently scheduled or predicted for this stop.",
                    systemImage: "clock"
                ))
            case .failed(let message):
                StatusView(kind: .error(message: message, retry: {
                    Task { await viewModel.loadArrivals() }
                }))
            case .loaded:
                List(viewModel.arrivals) { arrival in
                    NavigationLink(value: arrival) {
                        ArrivalRow(arrival: arrival)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadArrivals()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Arrival.self) { arrival in
            if arrival.isCanceled {
                StatusView(kind: .empty(
                    title: "Arrival cancelled",
                    message: "This bus arrival has been cancelled and is not operating.",
                    systemImage: "xmark.circle"
                ))
            } else if let vehicleNumber = arrival.vehicle, !vehicleNumber.isEmpty {
                MapView(vehicleNumber: vehicleNumber)
            } else if arrival.estimated {
                StatusView(kind: .empty(
                    title: "Vehicle not yet assigned",
                    message: "This live arrival doesn't have a vehicle number to track yet.",
                    systemImage: "location.slash"
                ))
            } else {
                StatusView(kind: .empty(
                    title: "Scheduled arrival",
                    message: "This is a scheduled arrival. Vehicle tracking is only available for live estimates.",
                    systemImage: "clock"
                ))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    MarqueeText(text: stop.name, font: .headline)
                        .frame(width: 220)
                    Text(stopSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let refreshSubtitle {
                        Text(refreshSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // Note: toggleFavorite itself fires a success/warning
                // haptic, so no separate tap haptic is added here to
                // avoid a double-buzz.
                Button {
                    favoritesManager.toggleFavorite(stop)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(stop) ? "star.fill" : "star")
                        .foregroundStyle(favoritesManager.isFavorite(stop) ? .yellow : .primary)
                }
                .modifier(GlassButtonModifier())
            }
        }
        .task {
            favoritesManager.recordRecent(stop)
            await viewModel.loadArrivals()
        }
    }
}

#Preview {
    NavigationStack {
        StopDetailView(stop: Stop.sampleStops[0])
            .environmentObject(FavoritesManager())
    }
}
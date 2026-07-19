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

    /// "Routes 1, 2, 8" line, shown under the stop number when the stop
    /// has known route data, so riders can see what serves this stop
    /// without scanning the arrivals list below.
    private var routesSubtitle: String? {
        guard !stop.routeShortNames.isEmpty else { return nil }
        return "Routes \(stop.routeShortNames.joined(separator: ", "))"
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
                    .transition(.opacity)
            case .empty:
                StatusView(kind: .empty(
                    title: "No arrivals right now",
                    message: "There are no buses currently scheduled or predicted for this stop.",
                    systemImage: "clock"
                ))
                .transition(.opacity)
            case .failed(let message):
                StatusView(kind: .error(message: message, retry: {
                    Task { await viewModel.loadArrivals() }
                }))
                .transition(.opacity)
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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Arrival.self) { arrival in
         Group {
            if arrival.isCanceled {
                StatusView(kind: .empty(
                    title: "Arrival cancelled",
                    message: "This bus arrival has been cancelled and is not operating.",
                    systemImage: "xmark.circle"
                ))
            } else if arrival.estimated, let vehicleNumber = arrival.vehicle, !vehicleNumber.isEmpty {
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
                    message: "This bus is scheduled to arrive at the posted time. Live vehicle tracking isn't available for scheduled (non-live) arrivals.",
                    systemImage: "clock"
                ))
            }
        }
        .id(arrival.id)
    }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    MarqueeText(text: stop.name, font: .headline)
                        .frame(width: 220)
                    Text(stopSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let routesSubtitle {
                        Text(routesSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
                        .symbolEffect(.bounce, value: favoritesManager.isFavorite(stop))
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: favoritesManager.isFavorite(stop))
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
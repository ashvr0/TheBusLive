import SwiftUI

struct StopDetailView: View {

    let stop: Stop

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @StateObject private var viewModel: StopViewModel

    init(stop: Stop) {
        self.stop = stop
        _viewModel = StateObject(wrappedValue: StopViewModel(stop: stop))
    }

    private var routesSubtitle: String? {
        guard !stop.routeShortNames.isEmpty else { return nil }
        return "Routes \(stop.routeShortNames.joined(separator: ", "))"
    }

    private var refreshSubtitle: String? {
        guard let lastRefreshed = viewModel.lastRefreshed else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return "Last refresh: \(formatter.string(from: lastRefreshed))"
    }

    /// Compact stop info shown as a list header instead of stacked in
    /// the nav bar: "Stop 137", then routes, then last refresh time.
    private var stopInfoHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Stop \(stop.stopID)")
                .font(.subheadline)
                .fontWeight(.semibold)
            if let routesSubtitle {
                Text(routesSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let refreshSubtitle {
                Text(refreshSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
                List {
                    Section {
                        stopInfoHeader
                    }
                    Section {
                        ForEach(viewModel.arrivals) { arrival in
                            NavigationLink(value: arrival) {
                                ArrivalRow(arrival: arrival)
                            }
                        }
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
                MarqueeText(text: stop.name, font: .headline)
                    .frame(maxWidth: 220)
            }
            ToolbarItem(placement: .topBarTrailing) {
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
            // A single task owns both the initial load and the recurring
            // poll, so the 30s interval is measured from the end of each
            // load rather than from view appearance. Splitting these into
            // two sibling tasks let a slow initial fetch and the first
            // poll land close together instead of being evenly spaced.
            favoritesManager.recordRecent(stop)
            while !Task.isCancelled {
                await viewModel.loadArrivals()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StopDetailView(stop: Stop.sampleStops[0])
            .environmentObject(FavoritesManager())
    }
}
import SwiftUI
import MapKit

struct AllStopsMapView: View {

    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 21.3069, longitude: -157.8583),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )

    @State private var cameraPosition: MapCameraPosition = .region(initialRegion)
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedStop: Stop?

    /// The stops actually rendered on the map. Recomputed only after the
    /// camera settles (see `regionUpdateTask`), rather than on every
    /// intermediate frame of a pinch/pan gesture, which is what was causing the lag when zooming.
    @State private var visibleStops: [Stop] = []
    @State private var regionUpdateTask: Task<Void, Never>?

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @AppStorage(AppPreferenceKeys.mapStyle) private var mapStyleRaw: String = AppMapStyleOption.standard.rawValue

    private var mapStyle: MapStyle {
        (AppMapStyleOption(rawValue: mapStyleRaw) ?? .standard).mapStyle
    }

    private var isZoomedInEnough: Bool {
        guard let region = visibleRegion else { return false }
        return region.span.latitudeDelta < 0.12
    }

    /// Above this many stops in view, MapKit's per-annotation SwiftUI
    /// views (each a real Button + label + icon) start costing enough
    /// layout/hit-testing time per frame to visibly stutter pinch/pan.
    /// Past this count we thin the results instead of rendering all of them.
    private static let maxRenderedPins = 150

    /// Filters stops for a given region, then thins the result down to
    /// `maxRenderedPins` by snapping to a coarse grid and keeping one
    /// stop per cell, so the pins that remain stay evenly spread across
    /// the visible area instead of clustering wherever the array
    /// happened to list stops first. Run off the main actor so large
    /// stop lists don't block scrolling/zooming.
    nonisolated private func computeVisibleStops(for region: MKCoordinateRegion, allStops: [Stop]) -> [Stop] {
        let latDelta = region.span.latitudeDelta / 2
        let lonDelta = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - latDelta
        let maxLat = region.center.latitude + latDelta
        let minLon = region.center.longitude - lonDelta
        let maxLon = region.center.longitude + lonDelta

        guard region.span.latitudeDelta < 0.12 else { return [] }

        let inRegion = allStops.filter {
            $0.latitude >= minLat && $0.latitude <= maxLat &&
            $0.longitude >= minLon && $0.longitude <= maxLon
        }

        guard inRegion.count > Self.maxRenderedPins else { return inRegion }

        // Divide the visible area into a grid sized so the number of
        // cells roughly matches the pin budget, then keep one stop per
        // occupied cell. This spreads the thinned-out pins evenly
        // rather than just truncating the array.
        let gridSize = Int(ceil(sqrt(Double(Self.maxRenderedPins))))
        let cellLat = region.span.latitudeDelta / Double(gridSize)
        let cellLon = region.span.longitudeDelta / Double(gridSize)

        var seenCells = Set<Int>()
        var thinned: [Stop] = []
        thinned.reserveCapacity(Self.maxRenderedPins)

        for stop in inRegion {
            let row = Int((stop.latitude - minLat) / max(cellLat, 0.0001))
            let col = Int((stop.longitude - minLon) / max(cellLon, 0.0001))
            let cellKey = row * gridSize + col
            if seenCells.insert(cellKey).inserted {
                thinned.append(stop)
            }
        }

        return thinned
    }

    /// Debounces rapid camera-change callbacks (fired continuously during
    /// pinch-zoom) so we only recompute + re-render pins once movement
    /// pauses briefly, instead of on every single frame.
    private func scheduleVisibleStopsUpdate(for region: MKCoordinateRegion) {
        regionUpdateTask?.cancel()
        let allStops = Stop.allStops
        regionUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000) // ~0.12s debounce
            guard !Task.isCancelled else { return }
            let filtered = computeVisibleStops(for: region, allStops: allStops)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                visibleStops = filtered
            }
        }
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(visibleStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Button {
                        HapticsManager.shared.light()
                        selectedStop = stop
                    } label: {
                        StopPin(isFavorite: favoritesManager.isFavorite(stop))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .mapStyle(mapStyle)
        .onMapCameraChange(frequency: .continuous) { context in
            // Keep visibleRegion live so the "zoom in" overlay reacts
            // immediately, but debounce the (potentially expensive)
            // stop filtering separately below.
            visibleRegion = context.region
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            scheduleVisibleStopsUpdate(for: context.region)
        }
        .overlay(alignment: .top) {
            if !isZoomedInEnough {
                Text("Zoom in to see stop pins")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackground(in: Capsule())
                    .padding(.top, 8)
            }
        }
        .onAppear {
            if let region = visibleRegion {
                scheduleVisibleStopsUpdate(for: region)
            } else {
                visibleRegion = Self.initialRegion
                scheduleVisibleStopsUpdate(for: Self.initialRegion)
            }
        }
        .navigationTitle("All Stops")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStop) { stop in
            NavigationStack {
                StopDetailView(stop: stop)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct StopPin: View {
    let isFavorite: Bool

    var body: some View {
        Image(systemName: isFavorite ? "star.circle.fill" : "mappin.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(isFavorite ? .yellow : Color.accentColor)
            .background(
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
            )
    }
}

#Preview {
    NavigationStack {
        AllStopsMapView()
            .environmentObject(FavoritesManager())
    }
}
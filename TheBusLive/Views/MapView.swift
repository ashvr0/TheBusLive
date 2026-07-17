import SwiftUI
import MapKit

struct MapView: View {

    let vehicleNumber: String

    @StateObject private var viewModel = VehicleMapViewModel()

    private var routePolylines: [[CLLocationCoordinate2D]] {
        guard let routeShortName = viewModel.vehicles.first?.routeShortName else { return [] }
        return RouteShapes.polylines(forRouteShortName: routeShortName)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.cameraPosition) {
                ForEach(Array(routePolylines.enumerated()), id: \.offset) { _, points in
                    MapPolyline(coordinates: points)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 3)
                }

                ForEach(viewModel.vehicles) { vehicle in
                    Annotation(vehicle.routeShortName ?? vehicle.number, coordinate: vehicle.coordinate) {
                        VehicleMarker(vehicle: vehicle)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .bottom)

            GlassGroup {
                switch viewModel.state {
                case .idle, .loading:
                    if viewModel.vehicles.isEmpty {
                        StatusView(kind: .loading)
                            .glassBackground(in: Rectangle())
                    }
                case .empty:
                    StatusView(kind: .empty(
                        title: "Vehicle not found",
                        message: "Vehicle \(vehicleNumber) isn't currently reporting a position.",
                        systemImage: "location.slash"
                    ))
                    .glassBackground(in: Rectangle())
                case .failed(let message):
                    StatusView(kind: .error(message: message, retry: {
                        Task { await viewModel.loadVehicle(number: vehicleNumber) }
                    }))
                    .glassBackground(in: Rectangle())
                case .loaded:
                    if let vehicle = viewModel.vehicles.first {
                        VehicleInfoCard(vehicle: vehicle)
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("Vehicle \(vehicleNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.startAutoRefresh(number: vehicleNumber)
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
}

private struct VehicleMarker: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 2)
        }
    }
}

private struct VehicleInfoCard: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Route \(vehicle.routeShortName ?? "?")")
                    .font(.headline)
                Spacer()
                if let minutes = vehicle.adherenceMinutes {
                    Text(adherenceText(minutes))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(minutes < 0 ? .red : .green)
                }
            }

            if let headsign = vehicle.headsign, !headsign.isEmpty {
                Text(headsign)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let lastMessage = vehicle.lastMessage, !lastMessage.isEmpty {
                Text("Last update: \(lastMessage)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(in: RoundedRectangle(cornerRadius: 16))
    }

    private func adherenceText(_ minutes: Int) -> String {
        if minutes == 0 { return "On time" }
        return minutes > 0 ? "\(minutes) min early" : "\(abs(minutes)) min late"
    }
}

#Preview {
    NavigationStack {
        MapView(vehicleNumber: "101")
    }
}

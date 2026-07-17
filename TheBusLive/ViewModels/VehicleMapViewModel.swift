import Foundation
import SwiftUI
import MapKit

@MainActor
final class VehicleMapViewModel: ObservableObject {

    enum LoadState {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published private(set) var vehicles: [Vehicle] = []
    @Published private(set) var state: LoadState = .idle
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.3069, longitude: -157.8583),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
    )

    private let client: APIClient
    private var refreshTask: Task<Void, Never>?

    init(client: APIClient = .shared) {
        self.client = client
    }

    func loadVehicle(number: String) async {
        state = .loading
        do {
            let response = try await client.fetchVehicle(number: number)

            if let message = response.errorMessage {
                state = .failed(message)
                vehicles = []
                return
            }

            let results = response.vehicle ?? []
            vehicles = results
            state = results.isEmpty ? .empty : .loaded

            if let first = results.first {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: first.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            }
        } catch let error as APIError {
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Polls a vehicle's position every 30 seconds, matching TheBus's own
    /// approximately one minute AVL refresh interval with headroom.
    func startAutoRefresh(number: String) {
        stopAutoRefresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadVehicle(number: number)
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

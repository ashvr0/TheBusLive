import SwiftUI
import MapKit

struct RouteView: View {

    let route: BusRoute

    private var polylines: [[CLLocationCoordinate2D]] {
        RouteShapes.polylines(forRouteShortName: route.routeNum)
    }

    var body: some View {
        List {
            if !polylines.isEmpty {
                Section {
                    Map {
                        ForEach(Array(polylines.enumerated()), id: \.offset) { _, points in
                            MapPolyline(coordinates: points)
                                .stroke(Color.accentColor, lineWidth: 3)
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                }
            }

            Section("Route") {
                LabeledContent("Number", value: route.routeNum)
                if let headsign = route.headsign, !headsign.isEmpty {
                    LabeledContent("Headsign", value: headsign)
                }
                if let firstStop = route.firstStop, !firstStop.isEmpty {
                    LabeledContent("Start / end", value: firstStop)
                }
                if let shapeID = route.shapeID, !shapeID.isEmpty {
                    LabeledContent("Shape ID", value: shapeID)
                }
            }

            Section {
                Text(APIConfig.attributionText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Route \(route.routeNum)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RouteView(route: BusRoute(routeNum: "8", shapeID: "8001", firstStop: "Ala Moana - Airport", headsign: "Ala Moana Center"))
    }
}

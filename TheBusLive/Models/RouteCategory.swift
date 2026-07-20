import Foundation
import SwiftUI

/// TheBus's lettered core Express routes (A, C, E, U, W) — the only
/// service tier the API's `routeNum` alone can reliably identify.
/// Limited Stop (1L, 2L) and Rush Hour Express (80-99, PH*, W1-W3) exist
/// as separate tiers on TheBus's site but aren't distinguishable from
/// `routeNum` without bundling TheBus's own route classification data,
/// so they're treated as standard routes here.
enum RouteCategory {
    private static let expressRouteNumbers: Set<String> = ["A", "C", "E", "U", "W"]

    static func isExpress(routeNum: String) -> Bool {
        expressRouteNumbers.contains(
            routeNum.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
    }
}

/// Small pill badge marking a route/arrival/stop as Express service.
struct ExpressBadge: View {
    var body: some View {
        Text("EXPRESS")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(BusRoute.expressColor, in: Capsule())
            .foregroundStyle(.white)
    }
}
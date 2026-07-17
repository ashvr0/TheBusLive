import SwiftUI

/// A single row showing one bus's predicted arrival at a stop. Reused by
/// both `StopDetailView` and, in a lighter mode, `HomeView`.
struct ArrivalRow: View {
    let arrival: Arrival

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(arrival.route)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(arrival.headsign)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if arrival.isCanceled {
                        Label("Canceled", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if arrival.estimated {
                        Label("Live", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Scheduled", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let direction = arrival.direction, !direction.isEmpty {
                        Text(direction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(arrival.stopTime)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(arrival.isCanceled ? .secondary : .primary)
                .strikethrough(arrival.isCanceled)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ArrivalRow(arrival: Arrival(
            id: "1", trip: "t1", route: "8", headsign: "Ala Moana Center",
            vehicle: "101", direction: "Eastbound", stopTime: "3:45 PM",
            date: nil, estimated: true, longitude: nil, latitude: nil,
            shape: nil, canceled: 0
        ))
        ArrivalRow(arrival: Arrival(
            id: "2", trip: "t2", route: "20", headsign: "Airport - Waikiki",
            vehicle: nil, direction: "Westbound", stopTime: "4:02 PM",
            date: nil, estimated: false, longitude: nil, latitude: nil,
            shape: nil, canceled: 1
        ))
    }
}

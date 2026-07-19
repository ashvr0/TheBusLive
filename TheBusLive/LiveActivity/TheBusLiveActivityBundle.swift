import WidgetKit
import SwiftUI

/// The single entry point for the TheBusLiveActivity extension target.
/// A widget extension must have exactly one `@main` — without this,
/// the extension has no valid entry point and ActivityKit reports
/// `.unsupportedTarget` when the host app tries to start an activity,
/// even though `areActivitiesEnabled` reports `true`.
@main
struct TheBusLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        BusArrivalLiveActivity()
    }
}

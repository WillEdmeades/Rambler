import SwiftUI
import WidgetKit

/// Bundles Rambler's lock screen and Dynamic Island widgets.
@main
struct RamblerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivityWidget()
    }
}

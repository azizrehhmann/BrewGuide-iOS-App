import WidgetKit
import SwiftUI
import ActivityKit

@main
struct BrewGuideWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        BrewLiveActivityWidget()
    }
}

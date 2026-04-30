import WidgetKit
import SwiftUI

@main
struct OutingCheckerWatchWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        OutingCheckerWatchPendingCountWidget()
        OutingCheckerWatchPendingTwoColumnWidget()
        OutingCheckerWatchPendingCornerWidget()
    }
}

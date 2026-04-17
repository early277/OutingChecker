import WidgetKit
import SwiftUI

@main
struct OutingCheckerWidgetBundle: WidgetBundle {
    var body: some Widget {
        OutingCheckerWidget()
        OutingCheckerTwoColumnWidget()
        OutingCheckerLockScreenCheckboxGridWidget()
        OutingCheckerLockScreenPendingListWidget()
        OutingCheckerLockScreenPendingTwoColumnWidget()
        OutingCheckerLockScreenAllItemsGridWidget()
    }
}

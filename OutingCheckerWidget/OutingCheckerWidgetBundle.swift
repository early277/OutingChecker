import WidgetKit
import SwiftUI

@main
struct OutingCheckerWidgetBundle: WidgetBundle {
    var body: some Widget {
        OutingCheckerWidget()
        OutingCheckerTwoColumnWidget()
        OutingCheckerPendingCheckboxDenseWidget()
        OutingCheckerLockScreenCheckboxGridWidget()
        OutingCheckerLockScreenPendingListWidget()
        OutingCheckerLockScreenPendingTwoColumnWidget()
        OutingCheckerLockScreenPendingThreeColumnWidget()
        OutingCheckerLockScreenAllItemsGridWidget()
    }
}

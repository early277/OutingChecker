import WidgetKit
import SwiftUI

@main
struct OutingCheckerWidgetBundle: WidgetBundle {
    var body: some Widget {
#if os(iOS)
        OutingCheckerWidget()
        OutingCheckerTwoColumnWidget()
        OutingCheckerPendingCheckboxDenseWidget()
#endif
        OutingCheckerLockScreenCheckboxGridWidget()
        OutingCheckerLockScreenPendingListWidget()
        OutingCheckerLockScreenPendingTwoColumnWidget()
        OutingCheckerWatchPendingTwoColumnWidget()
        OutingCheckerWatchPendingCountWidget()
#if os(watchOS)
        OutingCheckerWatchPendingCornerWidget()
#endif
        OutingCheckerLockScreenPendingThreeColumnWidget()
        OutingCheckerLockScreenAllItemsGridWidget()
    }
}

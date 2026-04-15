import WidgetKit
import SwiftUI

@main
struct OutingCheckerWidgetBundle: WidgetBundle {
    var body: some Widget {
        OutingCheckerSmallNamedWidget()
        OutingCheckerSmallSwitchOnlyWidget()
        OutingCheckerLargeNamedWidget()
        OutingCheckerLargeSwitchOnlyWidget()
        OutingCheckerLockScreenWidget()
    }
}

import AppIntents
import WidgetKit
import Foundation

struct ToggleItemIntent: AppIntent {
    static var title: LocalizedStringResource = "項目を切り替える"

    @Parameter(title: "項目ID")
    var itemID: String

    init() {}

    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        let store = ChecklistStore()
        if let uuid = UUID(uuidString: itemID) {
            _ = store.toggleItem(id: uuid)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

import Foundation

struct ChecklistStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        self.defaults = UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    func loadItems() -> [ChecklistItem] {
        guard let data = defaults.data(forKey: AppConfig.itemsKey),
              let items = try? decoder.decode([ChecklistItem].self, from: data) else {
            return [
                ChecklistItem(title: "財布", sortOrder: 0),
                ChecklistItem(title: "鍵", sortOrder: 1),
                ChecklistItem(title: "スマホ", sortOrder: 2)
            ]
        }
        return items.sorted { $0.sortOrder < $1.sortOrder }
    }

    func saveItems(_ items: [ChecklistItem]) {
        if let data = try? encoder.encode(items.sorted { $0.sortOrder < $1.sortOrder }) {
            defaults.set(data, forKey: AppConfig.itemsKey)
        }
    }

    @discardableResult
    func toggleItem(id: UUID, now: Date = Date()) -> [ChecklistItem] {
        var items = loadItems()
        applyResetIfNeeded(now: now, items: &items)

        guard let index = items.firstIndex(where: { $0.id == id }) else {
            saveItems(items)
            return items
        }

        items[index].isOn.toggle()
        saveItems(items)
        return items
    }

    @discardableResult
    func applyResetIfNeeded(now: Date = Date(), items: inout [ChecklistItem]) -> Bool {
        let calendar = Calendar.current
        var changed = false

        for index in items.indices {
            guard let rule = items[index].autoResetRule,
                  let trigger = ResetCalculator.latestTriggerDate(beforeOrAt: now, rule: rule, calendar: calendar) else {
                continue
            }

            if let last = items[index].lastAutoResetTriggerDate,
               calendar.compare(last, to: trigger, toGranularity: .minute) != .orderedAscending {
                continue
            }

            if items[index].isOn {
                items[index].isOn = false
                changed = true
            }
            items[index].lastAutoResetTriggerDate = trigger
            changed = true
        }

        if changed {
            saveItems(items)
        }
        return changed
    }

    func currentItemsApplyingResetIfNeeded(now: Date = Date()) -> [ChecklistItem] {
        var items = loadItems()
        _ = applyResetIfNeeded(now: now, items: &items)
        return items
    }
}

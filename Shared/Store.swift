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

    func loadRule() -> ResetRule {
        guard let data = defaults.data(forKey: AppConfig.resetRuleKey),
              let rule = try? decoder.decode(ResetRule.self, from: data) else {
            return .daily(hour: 5, minute: 0)
        }
        return rule
    }

    func saveRule(_ rule: ResetRule) {
        if let data = try? encoder.encode(rule) {
            defaults.set(data, forKey: AppConfig.resetRuleKey)
        }
    }

    func loadResetState() -> ResetState {
        guard let data = defaults.data(forKey: AppConfig.resetStateKey),
              let state = try? decoder.decode(ResetState.self, from: data) else {
            return ResetState(lastResetTriggerDate: nil)
        }
        return state
    }

    func saveResetState(_ state: ResetState) {
        if let data = try? encoder.encode(state) {
            defaults.set(data, forKey: AppConfig.resetStateKey)
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
        let rule = loadRule()
        var state = loadResetState()
        let calendar = Calendar.current

        guard let trigger = ResetCalculator.latestTriggerDate(beforeOrAt: now, rule: rule, calendar: calendar) else {
            return false
        }

        if let last = state.lastResetTriggerDate,
           calendar.compare(last, to: trigger, toGranularity: .minute) != .orderedAscending {
            return false
        }

        let hasAnyOn = items.contains(where: { $0.isOn })
        if hasAnyOn {
            for index in items.indices {
                items[index].isOn = false
            }
            saveItems(items)
        }

        state.lastResetTriggerDate = trigger
        saveResetState(state)
        return true
    }

    func currentItemsApplyingResetIfNeeded(now: Date = Date()) -> [ChecklistItem] {
        var items = loadItems()
        _ = applyResetIfNeeded(now: now, items: &items)
        return items
    }
}

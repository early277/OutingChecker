import Foundation

struct ChecklistStore {
    private struct LegacyResetState: Codable {
        var lastResetTriggerDate: Date?
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let sharedDefaults = UserDefaults(suiteName: AppConfig.appGroupID)
        self.defaults = sharedDefaults ?? .standard
        migrateLegacyStorageIfNeeded(sharedDefaults: sharedDefaults)
    }

    func loadItems() -> [ChecklistItem] {
        guard let data = defaults.data(forKey: AppConfig.itemsKey),
              let items = try? decoder.decode([ChecklistItem].self, from: data) else {
            return []
        }

        var sortedItems = items.sorted { $0.sortOrder < $1.sortOrder }
        if migrateLegacyGlobalResetIfNeeded(items: &sortedItems) {
            saveItems(sortedItems)
        }
        return sortedItems
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


    private func migrateLegacyStorageIfNeeded(sharedDefaults: UserDefaults?) {
        guard let sharedDefaults else { return }
        guard sharedDefaults.data(forKey: AppConfig.itemsKey) == nil else { return }

        let legacyCandidates: [UserDefaults] = [
            .standard,
            UserDefaults(suiteName: AppConfig.legacyUnsharedSuiteID)
        ].compactMap { $0 }

        for source in legacyCandidates {
            guard let data = source.data(forKey: AppConfig.itemsKey) else { continue }
            sharedDefaults.set(data, forKey: AppConfig.itemsKey)

            if let resetRuleData = source.data(forKey: AppConfig.resetRuleKey) {
                sharedDefaults.set(resetRuleData, forKey: AppConfig.resetRuleKey)
            }
            if let resetStateData = source.data(forKey: AppConfig.resetStateKey) {
                sharedDefaults.set(resetStateData, forKey: AppConfig.resetStateKey)
            }
            if source.object(forKey: AppConfig.perItemResetMigrationCompletedKey) != nil {
                sharedDefaults.set(source.bool(forKey: AppConfig.perItemResetMigrationCompletedKey),
                                   forKey: AppConfig.perItemResetMigrationCompletedKey)
            }
            break
        }
    }
    private func migrateLegacyGlobalResetIfNeeded(items: inout [ChecklistItem]) -> Bool {
        guard !defaults.bool(forKey: AppConfig.perItemResetMigrationCompletedKey) else {
            return false
        }
        defer {
            defaults.set(true, forKey: AppConfig.perItemResetMigrationCompletedKey)
            defaults.removeObject(forKey: AppConfig.resetRuleKey)
            defaults.removeObject(forKey: AppConfig.resetStateKey)
        }

        let legacyRule: ResetRule?
        if let data = defaults.data(forKey: AppConfig.resetRuleKey),
           let rule = try? decoder.decode(ResetRule.self, from: data) {
            legacyRule = rule
        } else if defaults.data(forKey: AppConfig.resetStateKey) != nil {
            legacyRule = .daily(hour: 5, minute: 0)
        } else {
            legacyRule = nil
        }

        guard let legacyRule else {
            return false
        }

        let legacyState: LegacyResetState?
        if let stateData = defaults.data(forKey: AppConfig.resetStateKey) {
            legacyState = try? decoder.decode(LegacyResetState.self, from: stateData)
        } else {
            legacyState = nil
        }

        var changed = false
        for index in items.indices where items[index].autoResetRule == nil {
            items[index].autoResetRule = legacyRule
            if items[index].lastAutoResetTriggerDate == nil {
                items[index].lastAutoResetTriggerDate = legacyState?.lastResetTriggerDate
            }
            changed = true
        }
        return changed
    }
}

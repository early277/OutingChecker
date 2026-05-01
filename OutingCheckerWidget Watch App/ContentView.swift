import SwiftUI
import WidgetKit
import Foundation
import WatchConnectivity
import Combine


private enum WatchStorage {
    static let appGroupID = "group.com.gmail.abyosida.OutingChecker"
    static let itemsKey = "outingChecker.items"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

private struct ChecklistItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var isOn: Bool
    var sortOrder: Int
    var autoResetRule: ResetRule?
    var lastAutoResetTriggerDate: Date?
}

private enum ResetRule: Codable {
    case daily(hour: Int, minute: Int)
    case dailyHours(hours: [Int])
    case weekday(weekday: Int, hour: Int, minute: Int)
    case weekdays(weekdays: [Int], hour: Int, minute: Int)
    case weekdaysHours(weekdays: [Int], hours: [Int])
    case nthWeekday(ordinal: Int, weekday: Int, hour: Int, minute: Int)
    case nthWeekdays(ordinals: [Int], weekdays: [Int], hour: Int, minute: Int)
    case nthWeekdaysHours(ordinals: [Int], weekdays: [Int], hours: [Int])
    case nthWeekdayPreviousDay(ordinal: Int, weekday: Int, hour: Int, minute: Int)
    case nthWeekdaysPreviousDay(ordinals: [Int], weekdays: [Int], hour: Int, minute: Int)
    case nthWeekdaysHoursPreviousDay(ordinals: [Int], weekdays: [Int], hours: [Int])
}

private struct ChecklistStore {
    private let defaults = WatchStorage.defaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func loadItems() -> [ChecklistItem] {
        guard let data = defaults.data(forKey: WatchStorage.itemsKey),
              let decoded = try? decoder.decode([ChecklistItem].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.sortOrder < $1.sortOrder }
    }

    func saveItems(_ items: [ChecklistItem]) {
        if let data = try? encoder.encode(items.sorted(by: { $0.sortOrder < $1.sortOrder })) {
            defaults.set(data, forKey: WatchStorage.itemsKey)
        }
    }

    @discardableResult
    func applyResetIfNeeded(items: inout [ChecklistItem]) -> Bool {
        let now = Date()
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

    func toggleItem(id: UUID) -> [ChecklistItem] {
        var items = loadItems()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return items }
        items[index].isOn.toggle()
        saveItems(items)
        return items
    }
}

private enum ResetCalculator {
    static func latestTriggerDate(beforeOrAt now: Date, rule: ResetRule, calendar: Calendar) -> Date? {
        switch rule {
        case let .daily(hour, minute):
            return latestDailyTrigger(beforeOrAt: now, hour: hour, minute: minute, calendar: calendar)
        case let .dailyHours(hours):
            return hours.compactMap { latestDailyTrigger(beforeOrAt: now, hour: $0, minute: 0, calendar: calendar) }.max()
        case let .weekday(weekday, hour, minute):
            return latestWeekdayTrigger(beforeOrAt: now, weekday: weekday, hour: hour, minute: minute, calendar: calendar)
        case let .weekdays(weekdays, hour, minute):
            return weekdays.compactMap { latestWeekdayTrigger(beforeOrAt: now, weekday: $0, hour: hour, minute: minute, calendar: calendar) }.max()
        case let .weekdaysHours(weekdays, hours):
            var candidates: [Date] = []
            for weekday in weekdays { for hour in hours {
                if let c = latestWeekdayTrigger(beforeOrAt: now, weekday: weekday, hour: hour, minute: 0, calendar: calendar) { candidates.append(c) }
            }}
            return candidates.max()
        case let .nthWeekday(ordinal, weekday, hour, minute):
            return latestNthWeekdayTrigger(beforeOrAt: now, ordinal: ordinal, weekday: weekday, hour: hour, minute: minute, dayOffset: 0, calendar: calendar)
        case let .nthWeekdays(ordinals, weekdays, hour, minute):
            var candidates: [Date] = []
            for o in ordinals { for w in weekdays {
                if let c = latestNthWeekdayTrigger(beforeOrAt: now, ordinal: o, weekday: w, hour: hour, minute: minute, dayOffset: 0, calendar: calendar) { candidates.append(c) }
            }}
            return candidates.max()
        case let .nthWeekdaysHours(ordinals, weekdays, hours):
            var candidates: [Date] = []
            for o in ordinals { for w in weekdays { for h in hours {
                if let c = latestNthWeekdayTrigger(beforeOrAt: now, ordinal: o, weekday: w, hour: h, minute: 0, dayOffset: 0, calendar: calendar) { candidates.append(c) }
            }}}
            return candidates.max()
        case let .nthWeekdayPreviousDay(ordinal, weekday, hour, minute):
            return latestNthWeekdayTrigger(beforeOrAt: now, ordinal: ordinal, weekday: weekday, hour: hour, minute: minute, dayOffset: -1, calendar: calendar)
        case let .nthWeekdaysPreviousDay(ordinals, weekdays, hour, minute):
            var candidates: [Date] = []
            for o in ordinals { for w in weekdays {
                if let c = latestNthWeekdayTrigger(beforeOrAt: now, ordinal: o, weekday: w, hour: hour, minute: minute, dayOffset: -1, calendar: calendar) { candidates.append(c) }
            }}
            return candidates.max()
        case let .nthWeekdaysHoursPreviousDay(ordinals, weekdays, hours):
            var candidates: [Date] = []
            for o in ordinals { for w in weekdays { for h in hours {
                if let c = latestNthWeekdayTrigger(beforeOrAt: now, ordinal: o, weekday: w, hour: h, minute: 0, dayOffset: -1, calendar: calendar) { candidates.append(c) }
            }}}
            return candidates.max()
        }
    }

    private static func latestDailyTrigger(beforeOrAt now: Date, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        guard let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else { return nil }
        return candidate <= now ? candidate : calendar.date(byAdding: .day, value: -1, to: candidate)
    }

    private static func latestWeekdayTrigger(beforeOrAt now: Date, weekday: Int, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let start = calendar.startOfDay(for: day)
            guard calendar.component(.weekday, from: start) == weekday,
                  let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start),
                  candidate <= now else { continue }
            return candidate
        }
        return nil
    }

    private static func latestNthWeekdayTrigger(beforeOrAt now: Date, ordinal: Int, weekday: Int, hour: Int, minute: Int, dayOffset: Int, calendar: Calendar) -> Date? {
        for monthOffset in 0..<24 {
            guard let month = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let candidate = nthWeekdayDate(inSameMonthAs: month, ordinal: ordinal, weekday: weekday, hour: hour, minute: minute, dayOffset: dayOffset, calendar: calendar) else { continue }
            if candidate <= now { return candidate }
        }
        return nil
    }

    private static func nthWeekdayDate(inSameMonthAs date: Date, ordinal: Int, weekday: Int, hour: Int, minute: Int, dayOffset: Int, calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        var matches: [Date] = []
        for day in range {
            guard let current = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            if calendar.component(.weekday, from: current) == weekday { matches.append(current) }
        }
        guard ordinal >= 1, ordinal <= matches.count,
              let adjusted = calendar.date(byAdding: .day, value: dayOffset, to: matches[ordinal - 1]) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: adjusted)
    }
}

private enum WatchL10n {
    static func text(_ ja: String, _ en: String, _ ko: String) -> String {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "ja"
        if code.hasPrefix("ko") { return ko }
        if code.hasPrefix("en") { return en }
        return ja
    }
}

struct ContentView: View {
    @State private var items: [ChecklistItem] = []
    @State private var visibleItemIDs: Set<UUID> = []
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var syncManager = WatchSyncManager()
    private let store = ChecklistStore()

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var visibleWatchItems: [ChecklistItem] {
        items
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { visibleItemIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if visibleWatchItems.isEmpty {
                Text(WatchL10n.text("すべて達成", "All completed", "모두 완료"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleWatchItems) { item in
                    Button {
                        toggleItem(item)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.isOn ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isOn ? .green : .primary)
                            Text(item.title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(WatchL10n.text("リスト", "List", "목록"))
        .onAppear {
            reload()
            syncManager.requestLatestItems()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                reload()
                syncManager.requestLatestItems()
            }
        }
        .onReceive(syncManager.$latestItemsData) { data in
            guard let data else { return }
            applyIncomingItemsData(data)
        }
    }

    private func reload() {
        var latestItems = store.loadItems()
        let didApplyReset = store.applyResetIfNeeded(items: &latestItems)

        if didApplyReset, let data = try? encoder.encode(latestItems) {
            syncManager.sendUpdatedItems(data)
        }

        items = latestItems
        refreshVisibleItems(resetSnapshot: true)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func applyIncomingItemsData(_ data: Data) {
        guard var decoded = try? decoder.decode([ChecklistItem].self, from: data) else {
            return
        }

        let didApplyReset = store.applyResetIfNeeded(items: &decoded)
        store.saveItems(decoded)

        if didApplyReset, let encoded = try? encoder.encode(decoded) {
            syncManager.sendUpdatedItems(encoded)
        }
        items = decoded
        refreshVisibleItems(resetSnapshot: false)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func toggleItem(_ item: ChecklistItem) {
        let latest = store.toggleItem(id: item.id)
        if let data = try? encoder.encode(latest) {
            syncManager.sendUpdatedItems(data)
        }
        items = latest
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refreshVisibleItems(resetSnapshot: Bool) {
        let pendingIDs = Set(items.filter { !$0.isOn }.map(\.id))
        if resetSnapshot {
            visibleItemIDs = pendingIDs
        } else {
            visibleItemIDs.formUnion(pendingIDs)
        }
    }
}

private final class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var latestItemsData: Data?

    override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendUpdatedItems(_ data: Data) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil) { _ in }
        }
        session.transferUserInfo(["items": data])
    }

    func requestLatestItems() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if let data = session.applicationContext["items"] as? Data {
            latestItemsData = data
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        requestLatestItems()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let data = applicationContext["items"] as? Data else { return }
        DispatchQueue.main.async {
            self.latestItemsData = data
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        DispatchQueue.main.async {
            self.latestItemsData = messageData
        }
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}

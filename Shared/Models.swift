import Foundation

struct ChecklistItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isOn: Bool
    var sortOrder: Int

    init(id: UUID = UUID(), title: String, isOn: Bool = false, sortOrder: Int) {
        self.id = id
        self.title = title
        self.isOn = isOn
        self.sortOrder = sortOrder
    }
}

enum ResetRule: Codable, Hashable {
    case daily(hour: Int, minute: Int)
    case weekday(weekday: Int, hour: Int, minute: Int)
    case nthWeekday(ordinal: Int, weekday: Int, hour: Int, minute: Int)

    var summary: String {
        switch self {
        case let .daily(hour, minute):
            return String(format: "毎日 %02d:%02d", hour, minute)
        case let .weekday(weekday, hour, minute):
            return "毎週 \(weekdayJapanese(weekday)) \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekday(ordinal, weekday, hour, minute):
            return "毎月第\(ordinal)\(weekdayJapanese(weekday)) \(String(format: "%02d:%02d", hour, minute))"
        }
    }

    private func weekdayJapanese(_ value: Int) -> String {
        switch value {
        case 1: return "日曜"
        case 2: return "月曜"
        case 3: return "火曜"
        case 4: return "水曜"
        case 5: return "木曜"
        case 6: return "金曜"
        case 7: return "土曜"
        default: return "?"
        }
    }
}

struct ResetState: Codable, Hashable {
    /// 最後にリセットを実行した「発火時刻」
    var lastResetTriggerDate: Date?
}

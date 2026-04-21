import Foundation

struct ChecklistItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isOn: Bool
    var sortOrder: Int
    var autoResetRule: ResetRule?
    var lastAutoResetTriggerDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isOn: Bool = false,
        sortOrder: Int,
        autoResetRule: ResetRule? = nil,
        lastAutoResetTriggerDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isOn = isOn
        self.sortOrder = sortOrder
        self.autoResetRule = autoResetRule
        self.lastAutoResetTriggerDate = lastAutoResetTriggerDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isOn
        case sortOrder
        case autoResetRule
        case lastAutoResetTriggerDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        autoResetRule = try container.decodeIfPresent(ResetRule.self, forKey: .autoResetRule)
        lastAutoResetTriggerDate = try container.decodeIfPresent(Date.self, forKey: .lastAutoResetTriggerDate)
    }
}

enum ResetRule: Codable, Hashable {
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

    var summary: String {
        switch self {
        case let .daily(hour, minute):
            return String(format: "毎日 %02d:%02d", hour, minute)
        case let .dailyHours(hours):
            return "毎日 \(hourJapaneseList(hours))"
        case let .weekday(weekday, hour, minute):
            return "毎週 \(weekdayJapanese(weekday)) \(String(format: "%02d:%02d", hour, minute))"
        case let .weekdays(weekdays, hour, minute):
            return "毎週 \(weekdayJapaneseList(weekdays)) \(String(format: "%02d:%02d", hour, minute))"
        case let .weekdaysHours(weekdays, hours):
            return "毎週 \(weekdayJapaneseList(weekdays)) \(hourJapaneseList(hours))"
        case let .nthWeekday(ordinal, weekday, hour, minute):
            return "毎月第\(ordinal)\(weekdayJapanese(weekday)) \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdays(ordinals, weekdays, hour, minute):
            return "毎月 \(ordinalJapaneseList(ordinals))\(weekdayJapaneseList(weekdays)) \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdaysHours(ordinals, weekdays, hours):
            return "毎月 \(ordinalJapaneseList(ordinals))\(weekdayJapaneseList(weekdays)) \(hourJapaneseList(hours))"
        case let .nthWeekdayPreviousDay(ordinal, weekday, hour, minute):
            return "毎月第\(ordinal)\(weekdayJapanese(weekday))の前日 \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdaysPreviousDay(ordinals, weekdays, hour, minute):
            return "毎月 \(ordinalJapaneseList(ordinals))\(weekdayJapaneseList(weekdays))の前日 \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdaysHoursPreviousDay(ordinals, weekdays, hours):
            return "毎月 \(ordinalJapaneseList(ordinals))\(weekdayJapaneseList(weekdays))の前日 \(hourJapaneseList(hours))"
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

    private func weekdayJapaneseList(_ values: [Int]) -> String {
        let normalized = Array(Set(values)).sorted().map(weekdayJapanese)
        return normalized.isEmpty ? "未選択" : normalized.joined(separator: "・")
    }

    private func ordinalJapaneseList(_ values: [Int]) -> String {
        let normalized = Array(Set(values)).sorted().map { "第\($0)" }
        return normalized.isEmpty ? "未選択" : normalized.joined(separator: "・")
    }

    private func hourJapaneseList(_ values: [Int]) -> String {
        let normalized = Array(Set(values)).sorted().map { String(format: "%02d:00", $0) }
        return normalized.isEmpty ? "未選択" : normalized.joined(separator: "・")
    }
}

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
            return String(
                format: L10n.text("毎日 %02d:%02d", "Every day %02d:%02d", "매일 %02d:%02d"),
                hour,
                minute
            )
        case let .dailyHours(hours):
            return "\(L10n.text("毎日", "Every day", "매일")) \(hourLabelList(hours))"
        case let .weekday(weekday, hour, minute):
            return "\(L10n.text("毎週", "Every week", "매주")) \(weekdayLabel(weekday)) \(String(format: "%02d:%02d", hour, minute))"
        case let .weekdays(weekdays, hour, minute):
            return "\(L10n.text("毎週", "Every week", "매주")) \(weekdayLabelList(weekdays)) \(String(format: "%02d:%02d", hour, minute))"
        case let .weekdaysHours(weekdays, hours):
            return "\(L10n.text("毎週", "Every week", "매주")) \(weekdayLabelList(weekdays)) \(hourLabelList(hours))"
        case let .nthWeekday(ordinal, weekday, hour, minute):
            return "\(L10n.text("毎月", "Every month", "매월")) \(ordinalLabel(ordinal))\(weekdayLabel(weekday)) \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdays(ordinals, weekdays, hour, minute):
            return "\(L10n.text("毎月", "Every month", "매월")) \(ordinalLabelList(ordinals))\(weekdayLabelList(weekdays)) \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdaysHours(ordinals, weekdays, hours):
            return "\(L10n.text("毎月", "Every month", "매월")) \(ordinalLabelList(ordinals))\(weekdayLabelList(weekdays)) \(hourLabelList(hours))"
        case let .nthWeekdayPreviousDay(ordinal, weekday, hour, minute):
            return "\(L10n.text("毎月", "Every month", "매월")) \(ordinalLabel(ordinal))\(weekdayLabel(weekday))\(L10n.text("の前日", " previous day", " 전날")) \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdaysPreviousDay(ordinals, weekdays, hour, minute):
            return "\(L10n.text("毎月", "Every month", "매월")) \(ordinalLabelList(ordinals))\(weekdayLabelList(weekdays))\(L10n.text("の前日", " previous day", " 전날")) \(String(format: "%02d:%02d", hour, minute))"
        case let .nthWeekdaysHoursPreviousDay(ordinals, weekdays, hours):
            return "\(L10n.text("毎月", "Every month", "매월")) \(ordinalLabelList(ordinals))\(weekdayLabelList(weekdays))\(L10n.text("の前日", " previous day", " 전날")) \(hourLabelList(hours))"
        }
    }

    private func weekdayLabel(_ value: Int) -> String {
        switch value {
        case 1: return L10n.text("日", "Sun", "일")
        case 2: return L10n.text("月", "Mon", "월")
        case 3: return L10n.text("火", "Tue", "화")
        case 4: return L10n.text("水", "Wed", "수")
        case 5: return L10n.text("木", "Thu", "목")
        case 6: return L10n.text("金", "Fri", "금")
        case 7: return L10n.text("土", "Sat", "토")
        default: return "?"
        }
    }

    private func weekdayLabelList(_ values: [Int]) -> String {
        let normalized = Array(Set(values)).sorted().map(weekdayLabel)
        return normalized.isEmpty ? L10n.text("未選択", "Not selected", "선택 안 됨") : normalized.joined(separator: "・")
    }

    private func ordinalLabel(_ value: Int) -> String {
        switch AppLanguage.current {
        case .japanese:
            return "第\(value)"
        case .english:
            return "\(value)th"
        case .korean:
            return "\(value)번째"
        }
    }

    private func ordinalLabelList(_ values: [Int]) -> String {
        let normalized = Array(Set(values)).sorted().map(ordinalLabel)
        return normalized.isEmpty ? L10n.text("未選択", "Not selected", "선택 안 됨") : normalized.joined(separator: "・")
    }

    private func hourLabelList(_ values: [Int]) -> String {
        let normalized = Array(Set(values)).sorted().map { String(format: "%02d:00", $0) }
        return normalized.isEmpty ? L10n.text("未選択", "Not selected", "선택 안 됨") : normalized.joined(separator: "・")
    }
}

import Foundation

enum ResetCalculator {
    static func latestTriggerDate(beforeOrAt now: Date, rule: ResetRule, calendar: Calendar) -> Date? {
        switch rule {
        case let .daily(hour, minute):
            return latestDailyTrigger(beforeOrAt: now, hour: hour, minute: minute, calendar: calendar)
        case let .weekday(weekday, hour, minute):
            return latestWeekdayTrigger(beforeOrAt: now, weekday: weekday, hour: hour, minute: minute, calendar: calendar)
        case let .weekdays(weekdays, hour, minute):
            return weekdays
                .compactMap { latestWeekdayTrigger(beforeOrAt: now, weekday: $0, hour: hour, minute: minute, calendar: calendar) }
                .max()
        case let .nthWeekday(ordinal, weekday, hour, minute):
            return latestNthWeekdayTrigger(beforeOrAt: now, ordinal: ordinal, weekday: weekday, hour: hour, minute: minute, calendar: calendar)
        case let .nthWeekdays(ordinals, weekdays, hour, minute):
            var candidates: [Date] = []
            for ordinal in ordinals {
                for weekday in weekdays {
                    if let candidate = latestNthWeekdayTrigger(beforeOrAt: now, ordinal: ordinal, weekday: weekday, hour: hour, minute: minute, calendar: calendar) {
                        candidates.append(candidate)
                    }
                }
            }
            return candidates.max()
        }
    }

    private static func latestDailyTrigger(beforeOrAt now: Date, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        guard let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else { return nil }
        if candidate <= now {
            return candidate
        }
        return calendar.date(byAdding: .day, value: -1, to: candidate)
    }

    private static func latestWeekdayTrigger(beforeOrAt now: Date, weekday: Int, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let start = calendar.startOfDay(for: day)
            let weekdayValue = calendar.component(.weekday, from: start)
            guard weekdayValue == weekday else { continue }
            guard let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) else { continue }
            if candidate <= now {
                return candidate
            }
        }
        return nil
    }

    private static func latestNthWeekdayTrigger(beforeOrAt now: Date, ordinal: Int, weekday: Int, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        for monthOffset in 0..<24 {
            guard let month = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let candidate = nthWeekdayDate(inSameMonthAs: month, ordinal: ordinal, weekday: weekday, hour: hour, minute: minute, calendar: calendar) else {
                continue
            }
            if candidate <= now {
                return candidate
            }
        }
        return nil
    }

    private static func nthWeekdayDate(inSameMonthAs date: Date, ordinal: Int, weekday: Int, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let monthStart = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }

        var matches: [Date] = []
        for day in range {
            guard let current = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            if calendar.component(.weekday, from: current) == weekday {
                matches.append(current)
            }
        }

        guard ordinal >= 1, ordinal <= matches.count else { return nil }
        let base = matches[ordinal - 1]
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)
    }
}

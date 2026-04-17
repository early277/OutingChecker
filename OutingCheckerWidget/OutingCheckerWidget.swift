import WidgetKit
import SwiftUI
import AppIntents

struct OutingEntry: TimelineEntry {
    let date: Date
    let items: [ChecklistItem]
}

struct OutingProvider: TimelineProvider {
    private let store = ChecklistStore()

    func placeholder(in context: Context) -> OutingEntry {
        OutingEntry(date: Date(), items: [
            ChecklistItem(title: "財布", isOn: true, sortOrder: 0),
            ChecklistItem(title: "鍵", isOn: false, sortOrder: 1),
            ChecklistItem(title: "スマホ", isOn: true, sortOrder: 2),
            ChecklistItem(title: "ハンカチ", isOn: false, sortOrder: 3)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (OutingEntry) -> Void) {
        let items = store.currentItemsApplyingResetIfNeeded()
        completion(OutingEntry(date: Date(), items: items))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OutingEntry>) -> Void) {
        let now = Date()
        let items = store.currentItemsApplyingResetIfNeeded(now: now)
        let entry = OutingEntry(date: now, items: items)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct OutingCheckerWidget: Widget {
    let kind = "OutingCheckerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            OutingWidgetListView(entry: entry)
        }
        .configurationDisplayName("お出かけチェッカー")
        .description("ウィジェット上で直接 ON/OFF を切り替えます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct OutingCheckerTwoColumnWidget: Widget {
    let kind = "OutingCheckerTwoColumnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            OutingWidgetTwoColumnView(entry: entry)
        }
        .configurationDisplayName("お出かけチェッカー (2列)")
        .description("2列レイアウトで項目を表示します。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct OutingCheckerLockScreenWidget: Widget {
    let kind = "OutingCheckerLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("ロック画面: 残り項目数")
        .description("タイトルなしで残り項目数を表示します。")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct OutingCheckerLockScreenSixteenWidget: Widget {
    let kind = "OutingCheckerLockScreenSixteenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenSixteenWidgetView(entry: entry)
        }
        .configurationDisplayName("ロック画面: 16項目表示")
        .description("先頭16項目の状態を一覧表示します。")
        .supportedFamilies([.accessoryRectangular])
    }
}

private struct OutingWidgetListView: View {
    let entry: OutingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let maxCount = WidgetLayout.maxItemsForSingleColumn(family)
        let visibleItems = Array(entry.items.prefix(maxCount))

        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: WidgetLayout.rowSpacing(family)) {
                ForEach(visibleItems) { item in
                    WidgetItemButton(
                        item: item,
                        compact: false,
                        font: WidgetLayout.font(family)
                    )
                }

                if visibleItems.isEmpty {
                    Text("項目がありません")
                        .font(WidgetLayout.font(family))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(WidgetLayout.padding(family))
        .containerBackground(.background, for: .widget)
    }
}

private struct OutingWidgetTwoColumnView: View {
    let entry: OutingEntry
    @Environment(\.widgetFamily) private var family

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    var body: some View {
        let rows = WidgetLayout.maxItemsForTwoColumn(family) / 2
        let visibleSlots = WidgetLayout.columnMajorItems(entry.items, columns: 2, rows: rows)
        let visibleItems = visibleSlots.compactMap { $0 }

        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: WidgetLayout.rowSpacing(family)) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: WidgetLayout.rowSpacing(family)) {
                    ForEach(Array(visibleSlots.enumerated()), id: \.offset) { _, slot in
                        if let item = slot {
                            WidgetItemButton(item: item, compact: false, font: WidgetLayout.font(family))
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                    }
                }

                if visibleItems.isEmpty {
                    Text("項目がありません")
                        .font(WidgetLayout.font(family))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(WidgetLayout.padding(family))
        .containerBackground(.background, for: .widget)
    }
}

private struct LockScreenWidgetView: View {
    let entry: OutingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let doneCount = entry.items.filter(\.isOn).count
        let totalCount = entry.items.count
        let remainingCount = max(totalCount - doneCount, 0)

        Group {
            switch family {
            case .accessoryInline:
                Text("残り \(remainingCount)項目")
            case .accessoryCircular:
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: totalCount == 0 ? 0 : CGFloat(doneCount) / CGFloat(totalCount))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(remainingCount)")
                        .font(.caption2.bold())
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("残り \(remainingCount) / \(totalCount)")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            default:
                Text("残り \(remainingCount)")
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
    }
}

private struct LockScreenSixteenWidgetView: View {
    let entry: OutingEntry

    private var firstSixteenItems: [ChecklistItem] {
        Array(entry.items.prefix(16))
    }

    var body: some View {
        let doneCount = entry.items.filter(\.isOn).count
        let totalCount = entry.items.count
        let remainingCount = max(totalCount - doneCount, 0)
        let columns = Array(repeating: GridItem(.fixed(8), spacing: 4), count: 4)

        VStack(alignment: .leading, spacing: 4) {
            Text("残り \(remainingCount)")
                .font(.caption.bold())

            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    if index < firstSixteenItems.count {
                        Circle()
                            .fill(firstSixteenItems[index].isOn ? Color.green : Color.secondary.opacity(0.35))
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            Text("\(min(totalCount, 16))/16")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
    }
}

private struct WidgetItemButton: View {
    let item: ChecklistItem
    let compact: Bool
    let font: Font

    var body: some View {
        Button(intent: ToggleItemIntent(itemID: item.id.uuidString)) {
            HStack(spacing: 8) {
                WidgetSwitchView(isOn: item.isOn, compact: compact)
                Text(item.title)
                    .font(font)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WidgetSwitchView: View {
    let isOn: Bool
    let compact: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 12 : 14)
                .fill(isOn ? Color.green.opacity(0.9) : Color.gray.opacity(0.45))
                .frame(width: compact ? 40 : 50, height: compact ? 22 : 28)
            Text(isOn ? "済" : "未")
                .font(compact ? .caption2.bold() : .caption.weight(.bold))
                .foregroundStyle(.white)
                .offset(x: isOn ? (compact ? -7 : -9) : (compact ? 7 : 9))
            Circle()
                .fill(Color.white)
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                .offset(x: isOn ? (compact ? 9 : 11) : (compact ? -9 : -11))
                .shadow(radius: 1)
        }
        .accessibilityLabel(isOn ? "オン" : "オフ")
    }
}

private enum WidgetLayout {
    static func maxItemsForSingleColumn(_ family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 4
        case .systemMedium: return 4
        case .systemLarge: return 8
        default: return 4
        }
    }

    static func maxItemsForTwoColumn(_ family: WidgetFamily) -> Int {
        switch family {
        case .systemMedium: return 8
        case .systemLarge: return 16
        default: return 8
        }
    }

    static func rowSpacing(_ family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 8
        case .systemMedium: return 10
        case .systemLarge: return 12
        default: return 10
        }
    }

    static func padding(_ family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 12
        case .systemMedium: return 14
        case .systemLarge: return 16
        default: return 14
        }
    }

    static func font(_ family: WidgetFamily) -> Font {
        switch family {
        case .systemSmall: return .body
        case .systemMedium: return .body
        case .systemLarge: return .body
        default: return .body
        }
    }

    static func columnMajorItems(_ items: [ChecklistItem], columns: Int, rows: Int) -> [ChecklistItem?] {
        guard columns > 0, rows > 0 else { return [] }

        let maxCount = columns * rows
        let source = Array(items.prefix(maxCount))
        var arranged: [ChecklistItem?] = Array(repeating: nil, count: maxCount)

        for (index, item) in source.enumerated() {
            let row = index % rows
            let column = index / rows
            let displayIndex = row * columns + column
            if displayIndex < maxCount {
                arranged[displayIndex] = item
            }
        }

        return arranged
    }
}

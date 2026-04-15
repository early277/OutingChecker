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

struct OutingCheckerSmallNamedWidget: Widget {
    let kind = "OutingCheckerSmallNamedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            SwitchGridWidgetView(entry: entry, columns: 1, rows: 4, showTitle: true)
        }
        .configurationDisplayName("小: 1列4行(名前あり)")
        .description("スイッチと項目名を1列4行で表示します。")
        .supportedFamilies([.systemSmall])
    }
}

struct OutingCheckerSmallSwitchOnlyWidget: Widget {
    let kind = "OutingCheckerSmallSwitchOnlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            SwitchGridWidgetView(entry: entry, columns: 2, rows: 4, showTitle: false)
        }
        .configurationDisplayName("小: 2列4行(スイッチのみ)")
        .description("スイッチのみを2列4行で表示します。")
        .supportedFamilies([.systemSmall])
    }
}

struct OutingCheckerLargeNamedWidget: Widget {
    let kind = "OutingCheckerLargeNamedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            SwitchGridWidgetView(entry: entry, columns: 2, rows: 4, showTitle: true)
        }
        .configurationDisplayName("大: 2列4行(名前あり)")
        .description("スイッチと項目名を2列4行で表示します。")
        .supportedFamilies([.systemLarge])
    }
}

struct OutingCheckerLargeSwitchOnlyWidget: Widget {
    let kind = "OutingCheckerLargeSwitchOnlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            SwitchGridWidgetView(entry: entry, columns: 4, rows: 4, showTitle: false)
        }
        .configurationDisplayName("大: 4列4行(スイッチのみ)")
        .description("スイッチのみを4列4行で表示します。")
        .supportedFamilies([.systemLarge])
    }
}

struct OutingCheckerLockScreenWidget: Widget {
    let kind = "OutingCheckerLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("ロック画面: おでかけチェッカーウィジェット")
        .description("タップでアプリを開き、現在の進捗を確認できます。")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

private struct SwitchGridWidgetView: View {
    let entry: OutingEntry
    let columns: Int
    let rows: Int
    let showTitle: Bool

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)
    }

    var body: some View {
        let visibleSlots = WidgetLayout.columnMajorItems(entry.items, columns: columns, rows: rows)
        let visibleItems = visibleSlots.compactMap { $0 }

        VStack(spacing: 8) {
            if visibleItems.isEmpty {
                Text("項目がありません")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                    ForEach(Array(visibleSlots.enumerated()), id: \.offset) { _, slot in
                        if let item = slot {
                            WidgetItemButton(item: item, showTitle: showTitle)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 22)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

private struct LockScreenWidgetView: View {
    let entry: OutingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let doneCount = entry.items.filter(\.isOn).count
        let totalCount = entry.items.count

        Group {
            switch family {
            case .accessoryInline:
                Text("おでかけ: \(doneCount)/\(totalCount) 完了")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("おでかけチェッカーウィジェット")
                        .font(.caption2)
                    Text("\(doneCount)/\(totalCount) 完了")
                        .font(.headline)
                }
            default:
                Text("\(doneCount)/\(totalCount)")
            }
        }
    }
}

private struct WidgetItemButton: View {
    let item: ChecklistItem
    let showTitle: Bool

    var body: some View {
        Button(intent: ToggleItemIntent(itemID: item.id.uuidString)) {
            HStack(spacing: 6) {
                WidgetSwitchView(isOn: item.isOn)
                if showTitle {
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .allowsTightening(true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct WidgetSwitchView: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(isOn ? Color.green.opacity(0.9) : Color.gray.opacity(0.45))
                .frame(width: 38, height: 22)
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .offset(x: isOn ? 8 : -8)
                .shadow(radius: 1)
        }
        .accessibilityLabel(isOn ? "オン" : "オフ")
    }
}

private enum WidgetLayout {
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

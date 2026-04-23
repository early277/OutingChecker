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
        .configurationDisplayName(L10n.text("お出かけチェッカー", "Outing Checker", "외출 체크"))
        .description(L10n.text("ウィジェット上で直接 ON/OFF を切り替えます。", "Toggle items directly on the widget.", "위젯에서 항목을 직접 ON/OFF 전환합니다."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct OutingCheckerTwoColumnWidget: Widget {
    let kind = "OutingCheckerTwoColumnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            OutingWidgetTwoColumnView(entry: entry)
        }
        .configurationDisplayName(L10n.text("お出かけチェッカー (2列)", "Outing Checker (2 columns)", "외출 체크 (2열)"))
        .description(L10n.text("2列レイアウトで項目を表示します。", "Show items in a two-column layout.", "2열 레이아웃으로 항목을 표시합니다."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct OutingCheckerPendingCheckboxDenseWidget: Widget {
    let kind = "OutingCheckerPendingCheckboxDenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            OutingPendingCheckboxDenseView(entry: entry)
        }
        .configurationDisplayName(L10n.text("お出かけチェッカー (チェック・高密度)", "Outing Checker (Dense Checks)", "외출 체크 (고밀도 체크)"))
        .description(L10n.text("項目をそのままの順で、チェックボックスで多く表示します。", "Show more items with checkboxes in a dense layout.", "체크박스와 함께 더 많은 항목을 고밀도로 표시합니다."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct OutingCheckerLockScreenCheckboxGridWidget: Widget {
    let kind = "OutingCheckerLockScreenCheckboxGridWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenCheckboxGridView(entry: entry)
        }
        .configurationDisplayName(L10n.text("ロック画面(小): チェック4x4", "Lock Screen (S): Checks 4x4", "잠금화면(소): 체크 4x4"))
        .description(L10n.text("項目数分のチェックボックスを4行4列で表示します。", "Show checkboxes in a 4x4 grid.", "체크박스를 4x4 그리드로 표시합니다."))
        .supportedFamilies([.accessoryCircular])
    }
}

struct OutingCheckerLockScreenPendingListWidget: Widget {
    let kind = "OutingCheckerLockScreenPendingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenPendingListView(entry: entry)
        }
        .configurationDisplayName(L10n.text("ロック画面(大): 未達成4x1", "Lock Screen (L): Pending 4x1", "잠금화면(대): 미완료 4x1"))
        .description(L10n.text("未達成項目を4行1列で表示します。", "Show pending items in 4 rows and 1 column.", "미완료 항목을 4행 1열로 표시합니다."))
        .supportedFamilies([.accessoryRectangular])
    }
}

struct OutingCheckerLockScreenPendingTwoColumnWidget: Widget {
    let kind = "OutingCheckerLockScreenPendingTwoColumnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenPendingTwoColumnView(entry: entry)
        }
        .configurationDisplayName(L10n.text("ロック画面(大): 未達成4x2", "Lock Screen (L): Pending 4x2", "잠금화면(대): 미완료 4x2"))
        .description(L10n.text("未達成項目を4行2列で表示します。", "Show pending items in 4 rows and 2 columns.", "미완료 항목을 4행 2열로 표시합니다."))
        .supportedFamilies([.accessoryRectangular])
    }
}

struct OutingCheckerLockScreenPendingThreeColumnWidget: Widget {
    let kind = "OutingCheckerLockScreenPendingThreeColumnWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenPendingThreeColumnView(entry: entry)
        }
        .configurationDisplayName(L10n.text("ロック画面(大): 未達成4x3", "Lock Screen (L): Pending 4x3", "잠금화면(대): 미완료 4x3"))
        .description(L10n.text("未達成項目を4行3列で表示します。", "Show pending items in 4 rows and 3 columns.", "미완료 항목을 4행 3열로 표시합니다."))
        .supportedFamilies([.accessoryRectangular])
    }
}

struct OutingCheckerLockScreenAllItemsGridWidget: Widget {
    let kind = "OutingCheckerLockScreenAllItemsGridWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OutingProvider()) { entry in
            LockScreenAllItemsGridView(entry: entry)
        }
        .configurationDisplayName(L10n.text("ロック画面(大): 全項目4x4", "Lock Screen (L): All items 4x4", "잠금화면(대): 전체 항목 4x4"))
        .description(L10n.text("未達成/達成済みを4行4列で表示します。", "Show all items (done/pending) in a 4x4 grid.", "완료/미완료 전체 항목을 4x4 그리드로 표시합니다."))
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
                    Text(L10n.text("項目がありません", "No items", "항목이 없습니다"))
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
                    Text(L10n.text("項目がありません", "No items", "항목이 없습니다"))
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

private struct LockScreenCheckboxGridView: View {
    let entry: OutingEntry
    private let checkboxSize: CGFloat = 11.4

    private var arrangedItems: [ChecklistItem?] {
        WidgetLayout.columnMajorItems(entry.items, columns: 4, rows: 4)
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.fixed(checkboxSize), spacing: 3), count: 4)

        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LazyVGrid(columns: columns, alignment: .center, spacing: 3) {
                ForEach(0..<16, id: \.self) { index in
                    if let item = arrangedItems[index] {
                        Image(systemName: item.isOn ? "checkmark.square.fill" : "square")
                            .font(.system(size: checkboxSize, weight: .semibold))
                            .foregroundStyle(item.isOn ? .green : .primary)
                            .frame(width: checkboxSize, height: checkboxSize)
                    } else {
                        Image(systemName: "square")
                            .font(.system(size: checkboxSize, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.2))
                            .frame(width: checkboxSize, height: checkboxSize)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 0)
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
    }
}

private struct LockScreenPendingListView: View {
    let entry: OutingEntry

    private var pendingItems: [ChecklistItem] {
        entry.items.filter { !$0.isOn }
    }

    private var allCompleted: Bool {
        !entry.items.isEmpty && pendingItems.isEmpty
    }

    var body: some View {
        let arranged = WidgetLayout.columnMajorItems(pendingItems, columns: 1, rows: 4)

        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(arranged.enumerated()), id: \.offset) { _, slot in
                if let item = slot {
                    LockScreenItemRowView(item: item, fontSize: 10)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
        .overlay {
            if allCompleted {
                Text(L10n.text("すべて達成", "All completed", "모두 완료"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
    }
}

private struct LockScreenPendingTwoColumnView: View {
    let entry: OutingEntry

    private var pendingItems: [ChecklistItem] {
        entry.items.filter { !$0.isOn }
    }

    private var allCompleted: Bool {
        !entry.items.isEmpty && pendingItems.isEmpty
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 2)
        let arranged = WidgetLayout.columnMajorItems(pendingItems, columns: 2, rows: 4)

        LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
            ForEach(Array(arranged.enumerated()), id: \.offset) { _, slot in
                if let item = slot {
                    LockScreenItemRowView(item: item, fontSize: 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
        .overlay {
            if allCompleted {
                Text(L10n.text("すべて達成", "All completed", "모두 완료"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
    }
}

private struct LockScreenPendingThreeColumnView: View {
    let entry: OutingEntry

    private var pendingItems: [ChecklistItem] {
        entry.items.filter { !$0.isOn }
    }

    private var allCompleted: Bool {
        !entry.items.isEmpty && pendingItems.isEmpty
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 3)
        let arranged = WidgetLayout.columnMajorItems(pendingItems, columns: 3, rows: 4)

        LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
            ForEach(Array(arranged.enumerated()), id: \.offset) { _, slot in
                if let item = slot {
                    LockScreenItemRowView(item: item, fontSize: 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
        .overlay {
            if allCompleted {
                Text(L10n.text("すべて達成", "All completed", "모두 완료"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
    }
}

private struct LockScreenAllItemsGridView: View {
    let entry: OutingEntry

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 4)
        let arranged = WidgetLayout.columnMajorItems(entry.items, columns: 4, rows: 4)

        LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
            ForEach(Array(arranged.enumerated()), id: \.offset) { _, slot in
                if let item = slot {
                    LockScreenItemRowView(item: item, fontSize: 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
    }
}

private struct OutingPendingCheckboxDenseView: View {
    let entry: OutingEntry
    @Environment(\.widgetFamily) private var family

    private var columns: [GridItem] {
        [GridItem(.flexible(minimum: 0), spacing: 8), GridItem(.flexible(minimum: 0), spacing: 8)]
    }

    var body: some View {
        let arranged = WidgetLayout.columnMajorItems(
            entry.items,
            columns: 2,
            rows: WidgetLayout.maxRowsForDenseCheckbox(family)
        )
        let visibleItems = arranged.compactMap { $0 }

        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(Array(arranged.enumerated()), id: \.offset) { _, slot in
                    if let item = slot {
                        DenseWidgetCheckboxItem(item: item)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 14)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(WidgetLayout.padding(family))
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "outingchecker://open"))
        .overlay {
            if visibleItems.isEmpty {
                Text(L10n.text("項目がありません", "No items", "항목이 없습니다"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DenseWidgetCheckboxItem: View {
    let item: ChecklistItem

    var body: some View {
        Button(intent: ToggleItemIntent(itemID: item.id.uuidString)) {
            HStack(spacing: 4) {
                Image(systemName: item.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.isOn ? .secondary : .primary)
                Text(item.title)
                    .font(.system(size: 14.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(item.isOn ? .secondary : .primary)
                Spacer(minLength: 0)
            }
            .opacity(item.isOn ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct LockScreenItemRowView: View {
    let item: ChecklistItem
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: item.isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(item.isOn ? .green : .secondary)
            Text(item.title)
                .font(.system(size: fontSize))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
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
            Text(isOn ? "○" : "×")
                .font(compact ? .caption2.bold() : .caption.weight(.bold))
                .foregroundStyle(.white)
                .offset(x: isOn ? (compact ? -7 : -9) : (compact ? 7 : 9))
            Circle()
                .fill(Color.white)
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                .offset(x: isOn ? (compact ? 9 : 11) : (compact ? -9 : -11))
                .shadow(radius: 1)
        }
        .accessibilityLabel(isOn ? L10n.text("オン", "On", "켜짐") : L10n.text("オフ", "Off", "꺼짐"))
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

    static func maxRowsForDenseCheckbox(_ family: WidgetFamily) -> Int {
        switch family {
        case .systemMedium: return 6
        case .systemLarge: return 12
        default: return 6
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

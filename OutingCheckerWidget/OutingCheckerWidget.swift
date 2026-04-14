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
            ChecklistItem(title: "スマホ", isOn: true, sortOrder: 2)
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
            OutingWidgetView(entry: entry)
        }
        .configurationDisplayName("お出かけチェッカー")
        .description("ウィジェット上で直接 ON/OFF を切り替えます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct OutingWidgetView: View {
    let entry: OutingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let maxCount = maxItems(for: family)
        let visibleItems = Array(entry.items.prefix(maxCount))

        VStack(alignment: .leading, spacing: spacing(for: family)) {
            ForEach(visibleItems) { item in
                Button(intent: ToggleItemIntent(itemID: item.id.uuidString)) {
                    HStack(spacing: 10) {
                        WidgetSwitchView(isOn: item.isOn, compact: family == .systemSmall)
                        Text(item.title)
                            .font(font(for: family))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }

            if visibleItems.isEmpty {
                Text("項目がありません")
                    .font(font(for: family))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(padding(for: family))
        .containerBackground(.background, for: .widget)
    }

    private func maxItems(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 5
        case .systemLarge: return 10
        default: return 5
        }
    }

    private func spacing(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 8
        case .systemMedium: return 10
        case .systemLarge: return 12
        default: return 10
        }
    }

    private func padding(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: return 12
        case .systemMedium: return 14
        case .systemLarge: return 16
        default: return 14
        }
    }

    private func font(for family: WidgetFamily) -> Font {
        switch family {
        case .systemSmall: return .caption
        case .systemMedium: return .body
        case .systemLarge: return .body
        default: return .body
        }
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
            Circle()
                .fill(Color.white)
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                .offset(x: isOn ? (compact ? 9 : 11) : (compact ? -9 : -11))
                .shadow(radius: 1)
        }
        .accessibilityLabel(isOn ? "オン" : "オフ")
    }
}

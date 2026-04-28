import SwiftUI
import WidgetKit
import Foundation

private enum WatchStorage {
    static let appGroupID = "group.com.gmail.abyosida.OutingChecker"
    static let itemsKey = "outingChecker.items"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

private struct WatchChecklistItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var isOn: Bool
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isOn
        case sortOrder
    }

    init(id: UUID = UUID(), title: String, isOn: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.isOn = isOn
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

struct ContentView: View {
    @State private var items: [WatchChecklistItem] = []
    @Environment(\.scenePhase) private var scenePhase

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var pendingItems: [WatchChecklistItem] {
        items
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { !$0.isOn }
    }

    var body: some View {
        List {
            if pendingItems.isEmpty {
                Text("すべて達成")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pendingItems) { item in
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
        .navigationTitle("Watchチェック")
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reload()
            }
        }
    }

    private func reload() {
        guard let data = WatchStorage.defaults.data(forKey: WatchStorage.itemsKey),
              let decoded = try? decoder.decode([WatchChecklistItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func toggleItem(_ item: WatchChecklistItem) {
        var latest = items
        guard let index = latest.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        latest[index].isOn.toggle()
        latest.sort { $0.sortOrder < $1.sortOrder }

        if let data = try? encoder.encode(latest) {
            WatchStorage.defaults.set(data, forKey: WatchStorage.itemsKey)
        }

        items = latest
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}

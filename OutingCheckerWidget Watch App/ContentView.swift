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
    @State private var visibleItemIDs: Set<UUID> = []
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var syncManager = WatchSyncManager()

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var visibleWatchItems: [WatchChecklistItem] {
        items
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { visibleItemIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if visibleWatchItems.isEmpty {
                Text("すべて達成")
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
        .navigationTitle("Watchチェック")
        .onAppear {
            reload()
            syncManager.requestLatestItems()
            refreshVisibleItems()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                reload()
                syncManager.requestLatestItems()
                refreshVisibleItems()
            }
        }
        .onReceive(syncManager.$latestItemsData) { data in
            guard let data else { return }
            applyIncomingItemsData(data)
        }
    }

    private func reload() {
        guard let data = WatchStorage.defaults.data(forKey: WatchStorage.itemsKey),
              let decoded = try? decoder.decode([WatchChecklistItem].self, from: data) else {
            return
        }
        items = decoded
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func applyIncomingItemsData(_ data: Data) {
        guard let decoded = try? decoder.decode([WatchChecklistItem].self, from: data) else {
            return
        }
        items = decoded
        WatchStorage.defaults.set(data, forKey: WatchStorage.itemsKey)
        refreshVisibleItems()
        WidgetCenter.shared.reloadAllTimelines()
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
            syncManager.sendUpdatedItems(data)
        }

        items = latest
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refreshVisibleItems() {
        visibleItemIDs = Set(items.filter { !$0.isOn }.map(\.id))
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

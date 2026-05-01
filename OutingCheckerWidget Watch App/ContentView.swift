import SwiftUI
import WidgetKit
import Foundation
import WatchConnectivity
import Combine

struct ContentView: View {
    @State private var items: [ChecklistItem] = []
    @State private var visibleItemIDs: Set<UUID> = []
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var syncManager = WatchSyncManager()
    private let store = ChecklistStore()

    private let encoder = JSONEncoder()

    private var visibleWatchItems: [ChecklistItem] {
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
        items = store.currentItemsApplyingResetIfNeeded()
        refreshVisibleItems()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func applyIncomingItemsData(_ data: Data) {
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([ChecklistItem].self, from: data) else {
            return
        }
        store.saveItems(decoded)
        items = store.currentItemsApplyingResetIfNeeded()
        refreshVisibleItems()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func toggleItem(_ item: ChecklistItem) {
        let latest = store.toggleItem(id: item.id)
        if let data = try? encoder.encode(latest) {
            syncManager.sendUpdatedItems(data)
        }
        items = store.currentItemsApplyingResetIfNeeded()
        refreshVisibleItems()
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

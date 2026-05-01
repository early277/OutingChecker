import SwiftUI
import WidgetKit
import Foundation
import WatchConnectivity
import Combine

private enum WatchL10n {
    static func text(_ ja: String, _ en: String, _ ko: String) -> String {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "ja"
        if code.hasPrefix("ko") { return ko }
        if code.hasPrefix("en") { return en }
        return ja
    }
}

struct ContentView: View {
    @State private var items: [ChecklistItem] = []
    @State private var visibleItemIDs: Set<UUID> = []
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var syncManager = WatchSyncManager()
    private let store = ChecklistStore()

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var visibleWatchItems: [ChecklistItem] {
        items
            .sorted { $0.sortOrder < $1.sortOrder }
            .filter { visibleItemIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if visibleWatchItems.isEmpty {
                Text(WatchL10n.text("すべて達成", "All completed", "모두 완료"))
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
        .navigationTitle(WatchL10n.text("リスト", "List", "목록"))
        .onAppear {
            reload()
            syncManager.requestLatestItems()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                reload()
                syncManager.requestLatestItems()
            }
        }
        .onReceive(syncManager.$latestItemsData) { data in
            guard let data else { return }
            applyIncomingItemsData(data)
        }
    }

    private func reload() {
        items = store.currentItemsApplyingResetIfNeeded()
        if let data = try? encoder.encode(items) {
            syncManager.sendUpdatedItems(data)
        }
        refreshVisibleItems(resetSnapshot: true)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func applyIncomingItemsData(_ data: Data) {
        guard var decoded = try? decoder.decode([ChecklistItem].self, from: data) else {
            return
        }

        let didApplyReset = store.applyResetIfNeeded(items: &decoded)
        store.saveItems(decoded)

        if didApplyReset, let encoded = try? encoder.encode(decoded) {
            syncManager.sendUpdatedItems(encoded)
        }
        items = decoded
        refreshVisibleItems(resetSnapshot: false)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func toggleItem(_ item: ChecklistItem) {
        let latest = store.toggleItem(id: item.id)
        if let data = try? encoder.encode(latest) {
            syncManager.sendUpdatedItems(data)
        }
        items = latest
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refreshVisibleItems(resetSnapshot: Bool) {
        let pendingIDs = Set(items.filter { !$0.isOn }.map(\.id))
        if resetSnapshot {
            visibleItemIDs = pendingIDs
        } else {
            visibleItemIDs.formUnion(pendingIDs)
        }
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

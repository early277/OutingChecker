import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var items: [ChecklistItem] = []
    @Environment(\.scenePhase) private var scenePhase

    private let store = ChecklistStore()

    private var pendingItems: [ChecklistItem] {
        items.filter { !$0.isOn }
    }

    var body: some View {
        List {
            if pendingItems.isEmpty {
                Text(L10n.text("すべて達成", "All completed", "모두 완료"))
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
        .navigationTitle(L10n.text("Watchチェック", "Watch Checklist", "Watch 체크"))
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reload()
            }
        }
    }

    private func reload() {
        items = store.currentItemsApplyingResetIfNeeded()
    }

    private func toggleItem(_ item: ChecklistItem) {
        var latest = store.currentItemsApplyingResetIfNeeded()
        guard let index = latest.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        latest[index].isOn.toggle()
        store.saveItems(latest)
        items = latest
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    ContentView()
}

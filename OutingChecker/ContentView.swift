import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var items: [ChecklistItem] = []
    @State private var newTitle = ""
    @State private var rule: ResetRule = .daily(hour: 5, minute: 0)
    @State private var selectedRuleMode: RuleMode = .daily
    @State private var selectedWeekday = 2
    @State private var selectedOrdinal = 1
    @State private var time = DateComponents(calendar: .current, hour: 5, minute: 0).date ?? Date()

    private let store = ChecklistStore()

    enum RuleMode: String, CaseIterable, Identifiable {
        case daily = "毎日"
        case weekday = "曜日"
        case nthWeekday = "第n曜日"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("項目") {
                    HStack {
                        TextField("新しい項目", text: $newTitle)
                        Button("追加", action: addItem)
                            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if items.isEmpty {
                        Text("項目がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            HStack {
                                SwitchPreview(isOn: item.isOn)
                                Text(item.title)
                            }
                        }
                        .onDelete(perform: deleteItems)
                        .onMove(perform: moveItems)
                    }
                }

                Section("自動リセット") {
                    Picker("方式", selection: $selectedRuleMode) {
                        ForEach(RuleMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedRuleMode == .weekday || selectedRuleMode == .nthWeekday {
                        Picker("曜日", selection: $selectedWeekday) {
                            Text("日曜").tag(1)
                            Text("月曜").tag(2)
                            Text("火曜").tag(3)
                            Text("水曜").tag(4)
                            Text("木曜").tag(5)
                            Text("金曜").tag(6)
                            Text("土曜").tag(7)
                        }
                    }

                    if selectedRuleMode == .nthWeekday {
                        Picker("第何", selection: $selectedOrdinal) {
                            ForEach(1...5, id: \.self) { value in
                                Text("第\(value)").tag(value)
                            }
                        }
                    }

                    DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)

                    Button("設定を保存", action: saveRule)
                    Text("現在: \(rule.summary)")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            .navigationTitle("お出かけチェッカー")
            .toolbar { EditButton() }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        items = store.currentItemsApplyingResetIfNeeded()
        rule = store.loadRule()
        syncEditor(with: rule)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var current = store.loadItems()
        current.append(ChecklistItem(title: title, sortOrder: current.count))
        store.saveItems(current)
        newTitle = ""
        items = store.currentItemsApplyingResetIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func deleteItems(at offsets: IndexSet) {
        var current = store.loadItems()
        current.remove(atOffsets: offsets)
        normalizeSortOrder(&current)
        store.saveItems(current)
        items = store.currentItemsApplyingResetIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var current = store.loadItems()
        current.move(fromOffsets: source, toOffset: destination)
        normalizeSortOrder(&current)
        store.saveItems(current)
        items = store.currentItemsApplyingResetIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func normalizeSortOrder(_ list: inout [ChecklistItem]) {
        for index in list.indices {
            list[index].sortOrder = index
        }
    }

    private func syncEditor(with rule: ResetRule) {
        let calendar = Calendar.current
        switch rule {
        case let .daily(hour, minute):
            selectedRuleMode = .daily
            time = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        case let .weekday(weekday, hour, minute):
            selectedRuleMode = .weekday
            selectedWeekday = weekday
            time = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        case let .nthWeekday(ordinal, weekday, hour, minute):
            selectedRuleMode = .nthWeekday
            selectedOrdinal = ordinal
            selectedWeekday = weekday
            time = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        }
    }

    private func saveRule() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 5
        let minute = comps.minute ?? 0

        let newRule: ResetRule
        switch selectedRuleMode {
        case .daily:
            newRule = .daily(hour: hour, minute: minute)
        case .weekday:
            newRule = .weekday(weekday: selectedWeekday, hour: hour, minute: minute)
        case .nthWeekday:
            newRule = .nthWeekday(ordinal: selectedOrdinal, weekday: selectedWeekday, hour: hour, minute: minute)
        }

        store.saveRule(newRule)
        rule = newRule
        items = store.currentItemsApplyingResetIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct SwitchPreview: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isOn ? Color.green.opacity(0.85) : Color.gray.opacity(0.5))
                .frame(width: 52, height: 30)
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .offset(x: isOn ? 11 : -11)
                .shadow(radius: 1)
        }
    }
}

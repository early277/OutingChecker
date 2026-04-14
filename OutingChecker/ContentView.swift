import SwiftUI
import WidgetKit
import UIKit

struct ContentView: View {
    @State private var editMode: EditMode = .inactive
    @State private var items: [ChecklistItem] = []
    @State private var newTitle = ""
    @State private var editingItem: ChecklistItem?

    private let store = ChecklistStore()

    var body: some View {
        NavigationStack {
            contentForm
                .navigationTitle("おでかけチェッカーウィジェット")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isEditing ? "完了" : "編集") {
                            withAnimation {
                                editMode = isEditing ? .inactive : .active
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("おでかけチェッカーウィジェット")
                            .font(.headline.weight(.semibold))
                            .scaleEffect(0.6)
                            .lineLimit(1)
                    }
                }
                .onAppear(perform: reload)
                .environment(\.editMode, $editMode)
                .sheet(item: $editingItem) { item in
                    ItemEditorView(item: item) { updated in
                        updateItem(updated)
                    }
                }
        }
    }

    private var contentForm: some View {
        Form {
            Section("項目") {
                addItemRow

                if items.isEmpty {
                    Text("項目がありません")
                        .foregroundStyle(.secondary)
                } else {
                    itemList
                }
            }

            Section("アプリ") {
                Button(role: .destructive) {
                    quitApp()
                } label: {
                    Text("アプリを終了")
                }
            }
        }
    }

    private var addItemRow: some View {
        HStack {
            TextField("新しい項目", text: $newTitle)
            Button("追加", action: addItem)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var itemList: some View {
        ForEach(items) { item in
            HStack {
                SwitchPreview(isOn: item.isOn)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                    Text(item.autoResetRule?.summary ?? "自動リセットなし")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("編集") {
                    editingItem = item
                }
            }
        }
        .onDelete(perform: deleteItems)
        .onMove(perform: moveItems)
    }

    private func reload() {
        items = store.currentItemsApplyingResetIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persistItems(mutating mutation: (inout [ChecklistItem]) -> Void) {
        var latest = store.currentItemsApplyingResetIfNeeded()
        mutation(&latest)
        normalizeSortOrder(&latest)
        store.saveItems(latest)
        items = store.currentItemsApplyingResetIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        persistItems { latest in
            latest.append(ChecklistItem(title: title, sortOrder: latest.count))
        }
        newTitle = ""
    }

    private func updateItem(_ updated: ChecklistItem) {
        persistItems { latest in
            guard let index = latest.firstIndex(where: { $0.id == updated.id }) else { return }
            latest[index] = updated
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        persistItems { latest in
            latest.remove(atOffsets: offsets)
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        persistItems { latest in
            latest.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func normalizeSortOrder(_ list: inout [ChecklistItem]) {
        for index in list.indices {
            list[index].sortOrder = index
        }
    }

    private var isEditing: Bool {
        editMode.isEditing
    }

    private func quitApp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }
}

private struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

    enum RuleMode: String, CaseIterable, Identifiable {
        case daily = "毎日"
        case weekday = "曜日"
        case nthWeekday = "第n曜日"
        var id: String { rawValue }
    }

    @State private var draft: ChecklistItem
    private let onSave: (ChecklistItem) -> Void

    @State private var autoResetEnabled: Bool
    @State private var selectedRuleMode: RuleMode
    @State private var selectedWeekdays: Set<Int>
    @State private var selectedOrdinals: Set<Int>
    @State private var time: Date

    init(item: ChecklistItem, onSave: @escaping (ChecklistItem) -> Void) {
        _draft = State(initialValue: item)
        self.onSave = onSave

        let initialRule = item.autoResetRule ?? .daily(hour: 5, minute: 0)
        _autoResetEnabled = State(initialValue: item.autoResetRule != nil)

        let calendar = Calendar.current
        switch initialRule {
        case let .daily(hour, minute):
            _selectedRuleMode = State(initialValue: .daily)
            _selectedWeekdays = State(initialValue: [2])
            _selectedOrdinals = State(initialValue: [1])
            _time = State(initialValue: calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date())
        case let .weekday(weekday, hour, minute):
            _selectedRuleMode = State(initialValue: .weekday)
            _selectedWeekdays = State(initialValue: [weekday])
            _selectedOrdinals = State(initialValue: [1])
            _time = State(initialValue: calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date())
        case let .weekdays(weekdays, hour, minute):
            _selectedRuleMode = State(initialValue: .weekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: [1])
            _time = State(initialValue: calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date())
        case let .nthWeekday(ordinal, weekday, hour, minute):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: [weekday])
            _selectedOrdinals = State(initialValue: [ordinal])
            _time = State(initialValue: calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date())
        case let .nthWeekdays(ordinals, weekdays, hour, minute):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: Set(ordinals))
            _time = State(initialValue: calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("項目名") {
                    TextField("項目名", text: $draft.title)
                }

                Section("自動リセット") {
                    Toggle("有効", isOn: $autoResetEnabled)

                    if autoResetEnabled {
                        Picker("方式", selection: $selectedRuleMode) {
                            ForEach(RuleMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedRuleMode == .weekday || selectedRuleMode == .nthWeekday {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("曜日（複数選択）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(weekdayOptions, id: \.value) { option in
                                    MultiSelectRow(
                                        title: option.title,
                                        isSelected: selectedWeekdays.contains(option.value)
                                    ) {
                                        toggleSelection(option.value, in: &selectedWeekdays)
                                    }
                                }
                            }
                        }

                        if selectedRuleMode == .nthWeekday {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("第何（複数選択）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(1...5, id: \.self) { value in
                                    MultiSelectRow(
                                        title: "第\(value)",
                                        isSelected: selectedOrdinals.contains(value)
                                    ) {
                                        toggleSelection(value, in: &selectedOrdinals)
                                    }
                                }
                            }
                        }

                        DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("項目を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if autoResetEnabled {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            let hour = comps.hour ?? 5
            let minute = comps.minute ?? 0

            switch selectedRuleMode {
            case .daily:
                draft.autoResetRule = .daily(hour: hour, minute: minute)
            case .weekday:
                let weekdays = selectedWeekdays.isEmpty ? [2] : Array(selectedWeekdays).sorted()
                if weekdays.count == 1, let weekday = weekdays.first {
                    draft.autoResetRule = .weekday(weekday: weekday, hour: hour, minute: minute)
                } else {
                    draft.autoResetRule = .weekdays(weekdays: weekdays, hour: hour, minute: minute)
                }
            case .nthWeekday:
                let ordinals = selectedOrdinals.isEmpty ? [1] : Array(selectedOrdinals).sorted()
                let weekdays = selectedWeekdays.isEmpty ? [2] : Array(selectedWeekdays).sorted()
                if ordinals.count == 1,
                   weekdays.count == 1,
                   let ordinal = ordinals.first,
                   let weekday = weekdays.first {
                    draft.autoResetRule = .nthWeekday(ordinal: ordinal, weekday: weekday, hour: hour, minute: minute)
                } else {
                    draft.autoResetRule = .nthWeekdays(ordinals: ordinals, weekdays: weekdays, hour: hour, minute: minute)
                }
            }
        } else {
            draft.autoResetRule = nil
            draft.lastAutoResetTriggerDate = nil
        }
        onSave(draft)
    }

    private var weekdayOptions: [(value: Int, title: String)] {
        [
            (1, "日曜"), (2, "月曜"), (3, "火曜"), (4, "水曜"),
            (5, "木曜"), (6, "金曜"), (7, "土曜")
        ]
    }

    private func toggleSelection(_ value: Int, in set: inout Set<Int>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

private struct MultiSelectRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SwitchPreview: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isOn ? Color.green.opacity(0.85) : Color.gray.opacity(0.5))
                .frame(width: 52, height: 30)
            Text(isOn ? "済" : "未")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .offset(x: isOn ? -9 : 9)
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .offset(x: isOn ? 11 : -11)
                .shadow(radius: 1)
        }
    }
}

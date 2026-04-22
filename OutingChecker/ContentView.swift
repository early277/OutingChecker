import SwiftUI
import WidgetKit
import UIKit

struct ContentView: View {
    @State private var editMode: EditMode = .inactive
    @State private var items: [ChecklistItem] = []
    @State private var newTitle = ""
    @State private var editingItem: ChecklistItem?
    @Environment(\.scenePhase) private var scenePhase

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
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        reload()
                    }
                }
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
                Button {
                    toggleItem(item)
                } label: {
                    SwitchPreview(isOn: item.isOn)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title) を\(item.isOn ? "オフ" : "オン")にする")

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

    private func toggleItem(_ item: ChecklistItem) {
        persistItems { latest in
            guard let index = latest.firstIndex(where: { $0.id == item.id }) else { return }
            latest[index].isOn.toggle()
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
    @State private var selectedHours: Set<Int>
    @State private var usePreviousDayForNthWeekday: Bool

    init(item: ChecklistItem, onSave: @escaping (ChecklistItem) -> Void) {
        _draft = State(initialValue: item)
        self.onSave = onSave

        let initialRule = item.autoResetRule ?? .daily(hour: 5, minute: 0)
        _autoResetEnabled = State(initialValue: item.autoResetRule != nil)
        _usePreviousDayForNthWeekday = State(initialValue: false)

        switch initialRule {
        case let .daily(hour, _):
            _selectedRuleMode = State(initialValue: .daily)
            _selectedWeekdays = State(initialValue: [2])
            _selectedOrdinals = State(initialValue: [1])
            _selectedHours = State(initialValue: [hour])
        case let .dailyHours(hours):
            _selectedRuleMode = State(initialValue: .daily)
            _selectedWeekdays = State(initialValue: [2])
            _selectedOrdinals = State(initialValue: [1])
            _selectedHours = State(initialValue: Set(hours))
        case let .weekday(weekday, hour, _):
            _selectedRuleMode = State(initialValue: .weekday)
            _selectedWeekdays = State(initialValue: [weekday])
            _selectedOrdinals = State(initialValue: [1])
            _selectedHours = State(initialValue: [hour])
        case let .weekdays(weekdays, hour, _):
            _selectedRuleMode = State(initialValue: .weekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: [1])
            _selectedHours = State(initialValue: [hour])
        case let .weekdaysHours(weekdays, hours):
            _selectedRuleMode = State(initialValue: .weekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: [1])
            _selectedHours = State(initialValue: Set(hours))
        case let .nthWeekday(ordinal, weekday, hour, _):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: [weekday])
            _selectedOrdinals = State(initialValue: [ordinal])
            _selectedHours = State(initialValue: [hour])
        case let .nthWeekdays(ordinals, weekdays, hour, _):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: Set(ordinals))
            _selectedHours = State(initialValue: [hour])
        case let .nthWeekdaysHours(ordinals, weekdays, hours):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: Set(ordinals))
            _selectedHours = State(initialValue: Set(hours))
        case let .nthWeekdayPreviousDay(ordinal, weekday, hour, _):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: [weekday])
            _selectedOrdinals = State(initialValue: [ordinal])
            _selectedHours = State(initialValue: [hour])
            _usePreviousDayForNthWeekday = State(initialValue: true)
        case let .nthWeekdaysPreviousDay(ordinals, weekdays, hour, _):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: Set(ordinals))
            _selectedHours = State(initialValue: [hour])
            _usePreviousDayForNthWeekday = State(initialValue: true)
        case let .nthWeekdaysHoursPreviousDay(ordinals, weekdays, hours):
            _selectedRuleMode = State(initialValue: .nthWeekday)
            _selectedWeekdays = State(initialValue: Set(weekdays))
            _selectedOrdinals = State(initialValue: Set(ordinals))
            _selectedHours = State(initialValue: Set(hours))
            _usePreviousDayForNthWeekday = State(initialValue: true)
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
                                ChoiceChipGrid(
                                    options: weekdayOptions,
                                    selectedValues: $selectedWeekdays,
                                    columns: 4
                                )
                            }
                        }

                        if selectedRuleMode == .nthWeekday {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("第何（複数選択）")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ChoiceChipGrid(
                                    options: (1...5).map { (value: $0, title: "第\($0)") },
                                    selectedValues: $selectedOrdinals,
                                    columns: 5
                                )
                                Toggle("前日", isOn: $usePreviousDayForNthWeekday)
                                    .font(.caption)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("時刻（複数選択）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HourMultiSelectGrid(selectedHours: $selectedHours)
                        }
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
            let hours = selectedHours.isEmpty ? [5] : Array(selectedHours).sorted()

            switch selectedRuleMode {
            case .daily:
                if hours.count == 1, let hour = hours.first {
                    draft.autoResetRule = .daily(hour: hour, minute: 0)
                } else {
                    draft.autoResetRule = .dailyHours(hours: hours)
                }
            case .weekday:
                let weekdays = selectedWeekdays.isEmpty ? [2] : Array(selectedWeekdays).sorted()
                if weekdays.count == 1,
                   hours.count == 1,
                   let weekday = weekdays.first,
                   let hour = hours.first {
                    draft.autoResetRule = .weekday(weekday: weekday, hour: hour, minute: 0)
                } else if hours.count == 1, let hour = hours.first {
                    draft.autoResetRule = .weekdays(weekdays: weekdays, hour: hour, minute: 0)
                } else {
                    draft.autoResetRule = .weekdaysHours(weekdays: weekdays, hours: hours)
                }
            case .nthWeekday:
                let ordinals = selectedOrdinals.isEmpty ? [1] : Array(selectedOrdinals).sorted()
                let weekdays = selectedWeekdays.isEmpty ? [2] : Array(selectedWeekdays).sorted()
                if ordinals.count == 1,
                   weekdays.count == 1,
                   hours.count == 1,
                   let ordinal = ordinals.first,
                   let weekday = weekdays.first,
                   let hour = hours.first {
                    draft.autoResetRule = usePreviousDayForNthWeekday
                    ? .nthWeekdayPreviousDay(ordinal: ordinal, weekday: weekday, hour: hour, minute: 0)
                    : .nthWeekday(ordinal: ordinal, weekday: weekday, hour: hour, minute: 0)
                } else if hours.count == 1, let hour = hours.first {
                    draft.autoResetRule = usePreviousDayForNthWeekday
                    ? .nthWeekdaysPreviousDay(ordinals: ordinals, weekdays: weekdays, hour: hour, minute: 0)
                    : .nthWeekdays(ordinals: ordinals, weekdays: weekdays, hour: hour, minute: 0)
                } else {
                    draft.autoResetRule = usePreviousDayForNthWeekday
                    ? .nthWeekdaysHoursPreviousDay(ordinals: ordinals, weekdays: weekdays, hours: hours)
                    : .nthWeekdaysHours(ordinals: ordinals, weekdays: weekdays, hours: hours)
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

}

private struct HourMultiSelectGrid: View {
    @Binding var selectedHours: Set<Int>

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(0..<24, id: \.self) { hour in
                Button {
                    toggle(hour)
                } label: {
                    Text("\(hour)時")
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedHours.contains(hour) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                        .foregroundStyle(selectedHours.contains(hour) ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ hour: Int) {
        if selectedHours.contains(hour) {
            selectedHours.remove(hour)
        } else {
            selectedHours.insert(hour)
        }
    }
}

private struct ChoiceChipGrid: View {
    let options: [(value: Int, title: String)]
    @Binding var selectedValues: Set<Int>
    let columns: Int

    var body: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: columns)

        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.value) { option in
                Button {
                    toggle(option.value)
                } label: {
                    Text(option.title)
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedValues.contains(option.value)
                            ? Color.accentColor.opacity(0.2)
                            : Color.secondary.opacity(0.12)
                        )
                        .foregroundStyle(selectedValues.contains(option.value) ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ value: Int) {
        if selectedValues.contains(value) {
            selectedValues.remove(value)
        } else {
            selectedValues.insert(value)
        }
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

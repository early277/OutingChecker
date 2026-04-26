import SwiftUI
import WidgetKit
import UIKit

struct ContentView: View {
    let route: AppRoute
    @State private var editMode: EditMode = .inactive
    @State private var items: [ChecklistItem] = []
    @State private var newTitle = ""
    @State private var editingItem: ChecklistItem?
    @Environment(\.scenePhase) private var scenePhase

    private let store = ChecklistStore()

    var body: some View {
        NavigationStack {
            Group {
                if route == .watchChecklist {
                    watchChecklistContent
                } else {
                    contentForm
                }
            }
            .navigationTitle(route == .watchChecklist ? L10n.text("Watchチェック", "Watch Checklist", "Watch 체크") : "おでかけチェッカーウィジェット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if route == .main {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isEditing ? L10n.text("完了", "Done", "완료") : L10n.text("編集", "Edit", "편집")) {
                            withAnimation {
                                editMode = isEditing ? .inactive : .active
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(route == .watchChecklist
                         ? L10n.text("Watchチェック", "Watch Checklist", "Watch 체크")
                         : L10n.text("おでかけチェッカーウィジェット", "Outing Checker Widget", "외출 체크 위젯"))
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
            Section(L10n.text("項目", "Items", "항목")) {
                addItemRow

                if items.isEmpty {
                    Text(L10n.text("項目がありません", "No items", "항목이 없습니다"))
                        .foregroundStyle(.secondary)
                } else {
                    itemList
                }
            }

            Section(L10n.text("アプリ", "App", "앱")) {
                Button(role: .destructive) {
                    quitApp()
                } label: {
                    Text(L10n.text("アプリを終了", "Quit App", "앱 종료"))
                }
            }
        }
    }

    private var addItemRow: some View {
        HStack {
            TextField(L10n.text("新しい項目", "New item", "새 항목"), text: $newTitle)
            Button(L10n.text("追加", "Add", "추가"), action: addItem)
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
                .accessibilityLabel("\(item.title) \(item.isOn ? L10n.text("をオフにする", "turn off", "끄기") : L10n.text("をオンにする", "turn on", "켜기"))")

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                    Text(item.autoResetRule?.summary ?? L10n.text("自動リセットなし", "No auto reset", "자동 리셋 없음"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.text("編集", "Edit", "편집")) {
                    editingItem = item
                }
            }
        }
        .onDelete(perform: deleteItems)
        .onMove(perform: moveItems)
    }

    private var watchChecklistContent: some View {
        List {
            let pendingItems = items.filter { !$0.isOn }

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
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

        var title: String {
            switch self {
            case .daily:
                return L10n.text("毎日", "Daily", "매일")
            case .weekday:
                return L10n.text("曜日", "Weekdays", "요일")
            case .nthWeekday:
                return L10n.text("第n曜日", "Nth weekday", "n번째 요일")
            }
        }
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
                Section(L10n.text("項目名", "Item name", "항목명")) {
                    TextField(L10n.text("項目名", "Item name", "항목명"), text: $draft.title)
                }

                Section(L10n.text("自動リセット", "Auto reset", "자동 리셋")) {
                    Toggle(L10n.text("有効", "Enabled", "사용"), isOn: $autoResetEnabled)

                    if autoResetEnabled {
                        Picker(L10n.text("方式", "Mode", "방식"), selection: $selectedRuleMode) {
                            ForEach(RuleMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedRuleMode == .weekday || selectedRuleMode == .nthWeekday {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.text("曜日（複数選択）", "Weekdays (multi-select)", "요일(복수 선택)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                WeekdaySelectionView(options: weekdayOptions, selectedValues: $selectedWeekdays)
                            }
                        }

                        if selectedRuleMode == .nthWeekday {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.text("第何（複数選択）", "Week number (multi-select)", "몇째(복수 선택)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ChoiceChipGrid(
                                    options: (1...5).map { (value: $0, title: ordinalLabel($0)) },
                                    selectedValues: $selectedOrdinals,
                                    columns: 5
                                )
                                Toggle(L10n.text("前日", "Previous day", "전날"), isOn: $usePreviousDayForNthWeekday)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text("時刻（複数選択）", "Hours (multi-select)", "시간(복수 선택)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HourMultiSelectGrid(selectedHours: $selectedHours)
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("項目を編集", "Edit Item", "항목 편집"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("キャンセル", "Cancel", "취소")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("保存", "Save", "저장")) {
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
            (2, L10n.text("月", "Mon", "월")),
            (3, L10n.text("火", "Tue", "화")),
            (4, L10n.text("水", "Wed", "수")),
            (5, L10n.text("木", "Thu", "목")),
            (6, L10n.text("金", "Fri", "금")),
            (7, L10n.text("土", "Sat", "토")),
            (1, L10n.text("日", "Sun", "일"))
        ]
    }

    private func ordinalLabel(_ value: Int) -> String {
        switch AppLanguage.current {
        case .japanese:
            return "第\(value)"
        case .english:
            return "\(value)th"
        case .korean:
            return "\(value)번째"
        }
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
                    Text(hourLabel(hour))
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

    private func hourLabel(_ hour: Int) -> String {
        switch AppLanguage.current {
        case .japanese:
            return "\(hour)時"
        case .english:
            return "\(hour):00"
        case .korean:
            return "\(hour)시"
        }
    }
}

private struct WeekdaySelectionView: View {
    let options: [(value: Int, title: String)]
    @Binding var selectedValues: Set<Int>

    var body: some View {
        VStack(spacing: 8) {
            ChoiceChipGrid(
                options: Array(options.prefix(5)),
                selectedValues: $selectedValues,
                columns: 5,
                isCentered: true
            )
            ChoiceChipGrid(
                options: Array(options.suffix(2)),
                selectedValues: $selectedValues,
                columns: 2,
                isCentered: true
            )
        }
    }
}

private struct ChoiceChipGrid: View {
    let options: [(value: Int, title: String)]
    @Binding var selectedValues: Set<Int>
    let columns: Int
    var isCentered: Bool = false

    var body: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: columns)

        LazyVGrid(columns: gridColumns, alignment: .center, spacing: 8) {
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
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
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
            Text(switchMarkText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: isOn ? -11 : 11)
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .offset(x: isOn ? 11 : -11)
                .shadow(radius: 1)
        }
    }

    private var switchMarkText: String {
        if AppLanguage.current == .japanese {
            return isOn ? "済" : "未"
        }
        return isOn ? "○" : "×"
    }
}

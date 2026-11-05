//
//  PresetsListView.swift
//  MenuBarTimer
//

import SwiftUI

/// The right-hand side of the overlay: quick-start presets and the app menu.
struct PresetsListView: View {
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var groupsStore: TimerGroupsStore
    @ObservedObject var groupCoordinator: TimerGroupCoordinator
    @State private var isEditing = false
    /// Whether edit mode uses the wider column. Kept across edit sessions; ignored outside edit mode.
    @State private var isEditExpanded = false
    /// Reorders the presets above the stopwatch. Rows are 24pt tall with 8pt spacing.
    @StateObject private var reorderer = RowReorderer(rowStride: 32)
    @FocusState private var isEditButtonFocused: Bool
    @Environment(\.openSettings) private var openSettings

    private static let focusRingInset: CGFloat = 4
    /// The list's fixed width. `MainPanel` uses it to tell the presets column from the timer column.
    static let width: CGFloat = 280
    /// The list's width in expanded edit mode, which gives the group editor's name fields more room.
    static let expandedWidth: CGFloat = 400

    private var columnWidth: CGFloat {
        isEditing && isEditExpanded ? Self.expandedWidth : Self.width
    }

    /// The presets that are listed (and can be reordered) above the stopwatch. Drag indices refer
    /// to this list, not to `presetsStore.presets`, which also contains the stopwatch somewhere.
    private var reorderablePresets: [TimerPreset] {
        presetsStore.presets.filter { !$0.isStopwatch }
    }

    private var stopwatch: TimerPreset? {
        presetsStore.presets.first(where: { $0.isStopwatch })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .anchorPreference(key: PresetsHeaderBoundsKey.self, value: .bounds) { $0 }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(reorderablePresets) { preset in
                        presetRow(for: preset)
                    }
                    if isEditing {
                        addButton("Add Single Timer", systemImage: "plus.circle", color: .blue) {
                            presetsStore.addPreset()
                        }
                    }

                    if let stopwatch {
                        sectionHeader("Stopwatch")
                        presetRow(for: stopwatch)
                    }

                    if !groupsStore.groups.isEmpty {
                        sectionHeader("Timer Groups")
                        ForEach(groupsStore.groups) { group in
                            groupRow(for: group)
                        }
                    }

                    if isEditing {
                        addButton("Add Timer Group", systemImage: "rectangle.3.group", color: .purple) {
                            addGroup()
                        }
                    }
                }
                // The scroll view clips to its bounds, which would cut off the rows' focus rings.
                // Inset the content by the ring's width and widen the scroll view by the same amount.
                .padding(Self.focusRingInset)
            }
            .padding(-Self.focusRingInset)
        }
        .padding(24)
        .frame(width: columnWidth)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { MainPanel.presetsColumnWidth = $0 }
        .onDisappear { reorderer.reset() }
        // The Edit button is the initially focused control whenever the window opens.
        .onAppear { focusEditButton() }
        .onReceive(NotificationCenter.default.publisher(for: MainWindowController.didShowNotification)) { _ in
            focusEditButton()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Presets")
                .font(.headline)

            Spacer()

            if isEditing {
                let title = isEditExpanded ? "Collapse editor" : "Expand editor"
                Button {
                    isEditExpanded.toggle()
                } label: {
                    Image(systemName: isEditExpanded
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.glass)
                .help(title)
                .accessibilityLabel(title)
            }

            Button(isEditing ? "Done" : "Edit") {
                isEditing.toggle()
                reorderer.reset()
            }
            .buttonStyle(.glass)
            .focused($isEditButtonFocused)

            appMenu
        }
    }

    private var appMenu: some View {
        Menu {
            Button("About MenuBarTimer") {
                showAboutPanel()
            }
            Button("Settings…") {
                // An agent app isn't activated by opening Settings, so its window can open behind
                // other apps' windows. Activating also covers reopening an already-open window.
                NSApp.activate()
                openSettings()
            }
            Divider()
            Button("Quit MenuBarTimer") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(height: 13)
                .padding(.all, 5)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .frame(width: 22)
        .padding(.trailing, 3)
    }

    private func showAboutPanel() {
        let existingWindows = NSApp.windows
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
        // Float like the main panel, which would otherwise cover this window. AppKit has no reference
        // to the about panel and it doesn't reliably become key, so find it as the window that's new.
        for window in NSApp.windows where !existingWindows.contains(window) {
            window.level = .floating
        }
    }

    private func focusEditButton() {
        DispatchQueue.main.async { isEditButtonFocused = true }
    }

    // MARK: Shared row elements

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private func addButton(
        _ title: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .padding(.top, 4)
    }

    // MARK: Preset rows

    @ViewBuilder
    private func presetRow(for preset: TimerPreset) -> some View {
        if isEditing {
            editablePresetRow(for: preset)
        } else {
            selectablePresetRow(for: preset)
        }
    }

    private func editablePresetRow(for preset: TimerPreset) -> some View {
        let ids = reorderablePresetIDs
        return HStack(spacing: 8) {
            if preset.isStopwatch {
                Label("Stopwatch", systemImage: "stopwatch")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ReorderHandle(help: "Drag to rearrange preset")
                    .gesture(reorderer.gesture(for: preset.id, in: ids, onMove: movePreset))
                DurationPicker(duration: durationBinding(for: preset))
                RemoveButton { presetsStore.removePreset(preset) }
            }
        }
        // The stopwatch isn't in `ids`, so it never moves.
        .reorderableRow(preset.id, in: ids, reorderer: reorderer)
    }

    private func selectablePresetRow(for preset: TimerPreset) -> some View {
        let isSelected = presetsStore.selectedPresetID == preset.id
        return Button {
            select(preset)
        } label: {
            HStack {
                if preset.isStopwatch {
                    Label("Stopwatch", systemImage: "stopwatch")
                } else {
                    Text(preset.seconds.formattedClock)
                        .monospacedDigit()
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Color.blue : nil)
    }

    private func durationBinding(for preset: TimerPreset) -> Binding<TimeInterval> {
        Binding(
            get: {
                presetsStore.presets.first(where: { $0.id == preset.id })?.seconds ?? 0
            },
            set: { newDuration in
                guard let index = presetsStore.presets.firstIndex(where: { $0.id == preset.id }) else { return }
                presetsStore.presets[index].seconds = newDuration
            }
        )
    }

    // MARK: Group rows

    @ViewBuilder
    private func groupRow(for group: TimerGroup) -> some View {
        if isEditing {
            TimerGroupEditor(groupsStore: groupsStore, group: group, isExpanded: isEditExpanded)
        } else {
            selectableGroupRow(for: group)
        }
    }

    private func selectableGroupRow(for group: TimerGroup) -> some View {
        let isSelected = groupsStore.selectedGroupID == group.id
        return Button {
            select(group)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "rectangle.3.group")
                    Text(group.name)
                    Spacer()
                    if isSelected { Image(systemName: "checkmark") }
                }
                HStack(spacing: 8) {
                    ForEach(group.timers) { timer in
                        Text(timer.name + " " + (timer.type == .countUp ? "↑" : timer.seconds.formattedClock))
                            .foregroundStyle(timer.color)
                            .font(.caption)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .purple : nil)
    }

    // MARK: Selection
    //
    // Presets and groups are mutually exclusive: selecting one clears the other's selection.

    private func select(_ preset: TimerPreset) {
        presetsStore.select(preset)
        groupsStore.clearSelection()
        groupCoordinator.load(nil)
        timerModel.load(preset)
    }

    private func select(_ group: TimerGroup) {
        groupsStore.select(group)
        presetsStore.clearSelection()
        groupCoordinator.load(group)
    }

    private func addGroup() {
        groupsStore.addGroup()
        presetsStore.clearSelection()
        groupCoordinator.load(groupsStore.selectedGroup)
    }

    // MARK: Reordering

    private var reorderablePresetIDs: [UUID] { reorderablePresets.map(\.id) }

    private func movePreset(_ presetID: UUID, toReorderableIndex targetIndex: Int) {
        // Taking the target preset's place puts the dragged one before it when moving up and after
        // it when moving down, wherever the stopwatch sits in the array.
        let targetID = reorderablePresets[targetIndex].id
        guard let storeIndex = presetsStore.presets.firstIndex(where: { $0.id == targetID }) else { return }
        presetsStore.movePreset(presetID, toIndex: storeIndex)
    }
}

/// Edit-mode row for a timer group: its name and an editable line per timer.
private struct TimerGroupEditor: View {
    @ObservedObject var groupsStore: TimerGroupsStore
    let group: TimerGroup
    /// Whether this is the expanded editor, whose timer rows also have a drag handle for reordering
    /// and a color picker.
    let isExpanded: Bool
    @StateObject private var reorderer = RowReorderer(rowStride: Self.timerRowHeight + Self.rowSpacing)

    /// Every timer row is this tall, whatever controls it shows, so the reorder drag has a fixed stride.
    private static let timerRowHeight: CGFloat = 24
    private static let rowSpacing: CGFloat = 5

    /// The store's current copy of the group; `group` may be stale between edits.
    private var currentGroup: TimerGroup? {
        groupsStore.groups.first(where: { $0.id == group.id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            HStack {
                TextField("Group name", text: nameBinding)
                Button {
                    groupsStore.duplicate(group)
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help("Duplicate group")
                RemoveButton { groupsStore.remove(group) }
            }
            ForEach(group.timers) { timer in
                timerRow(for: timer)
            }
            Button {
                groupsStore.addTimer(to: group)
            } label: {
                Label("Add Timer", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .onDisappear { reorderer.reset() }
        .onChange(of: isExpanded) { reorderer.reset() }
    }

    private func timerRow(for timer: TimerPreset) -> some View {
        let ids = group.timers.map(\.id)
        return HStack(spacing: 5) {
            if isExpanded {
                ReorderHandle(help: "Drag to rearrange timer")
                    .gesture(reorderer.gesture(for: timer.id, in: ids) { id, targetIndex in
                        groupsStore.moveTimer(id, in: group, toIndex: targetIndex)
                    })
            }
            Picker("Type", selection: binding(for: timer, \.type)) {
                Image(systemName: "arrow.up").imageScale(.small).tag(TimerType.countUp)
                Image(systemName: "arrow.down").imageScale(.small).tag(TimerType.countdown)
            }
            .labelsHidden()
            .frame(width: 45)
            if isExpanded {
                TimerColorPicker(colorName: binding(for: timer, \.colorName), ownerID: timer.id)
            }
            TextField("Timer name", text: binding(for: timer, \.name))
            if timer.type == .countdown {
                DurationPicker(duration: binding(for: timer, \.seconds))
            }
            RemoveButton { groupsStore.removeTimer(timer, from: group) }
                .disabled(group.timers.count == 1)
        }
        .frame(height: Self.timerRowHeight)
        .reorderableRow(timer.id, in: ids, reorderer: reorderer)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { currentGroup?.name ?? "" },
            set: { newName in
                guard var updated = currentGroup else { return }
                updated.name = newName
                groupsStore.update(updated)
            }
        )
    }

    /// Binds one property of a timer in the group, reading and writing the store's current copy.
    private func binding<Value>(
        for timer: TimerPreset,
        _ keyPath: WritableKeyPath<TimerPreset, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                let currentTimer = currentGroup?.timers.first(where: { $0.id == timer.id })
                return (currentTimer ?? timer)[keyPath: keyPath]
            },
            set: { newValue in
                guard var updated = currentGroup,
                      let index = updated.timers.firstIndex(where: { $0.id == timer.id }) else { return }
                updated.timers[index][keyPath: keyPath] = newValue
                groupsStore.update(updated)
            }
        )
    }
}

/// The red minus button that deletes a preset, group or group timer in edit mode.
private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PresetsListView(
        timerModel: TimerModel(),
        presetsStore: PresetsStore(),
        groupsStore: TimerGroupsStore(),
        groupCoordinator: TimerGroupCoordinator()
    )
}

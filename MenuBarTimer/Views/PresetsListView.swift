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
    @State private var draggedPresetID: UUID?
    @State private var dragStartIndex: Int?
    @State private var dragTargetIndex: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var escapeMonitor: Any?
    @State private var isDragCancelled = false
    @FocusState private var isEditButtonFocused: Bool

    private let editRowStride: CGFloat = 32
    /// Virtual key code (`NSEvent.keyCode`) of the Escape key, which cancels a reorder drag.
    private static let escapeKeyCode: UInt16 = 53
    private static let focusRingInset: CGFloat = 4
    /// The list's fixed width. `MainPanel` uses it to tell the presets column from the timer column.
    static let width: CGFloat = 280

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
        .frame(width: Self.width)
        .onDisappear { resetDrag() }
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

            Button(isEditing ? "Done" : "Edit") {
                isEditing.toggle()
                resetDrag()
            }
            .buttonStyle(.glass)
            .focused($isEditButtonFocused)

            appMenu
        }
    }

    private var appMenu: some View {
        Menu {
            SettingsLink {
                Text("Settings…")
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
        let isDragged = draggedPresetID == preset.id
        return HStack(spacing: 8) {
            if preset.isStopwatch {
                Label("Stopwatch", systemImage: "stopwatch")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 24)
                    .contentShape(Rectangle())
                    .help("Drag to rearrange preset")
                    .gesture(reorderGesture(for: preset))
                DurationPicker(duration: durationBinding(for: preset))
                RemoveButton { presetsStore.removePreset(preset) }
            }
        }
        .offset(y: rowOffset(for: preset))
        .opacity(isDragged ? 0.65 : 1)
        .zIndex(isDragged ? 1 : 0)
        .animation(isDragged ? nil : .easeOut(duration: 0.1), value: dragTargetIndex)
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
            TimerGroupEditor(groupsStore: groupsStore, group: group)
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

    private func reorderGesture(for preset: TimerPreset) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                guard !isDragCancelled else { return }
                if draggedPresetID == nil {
                    beginDrag(of: preset)
                }

                guard draggedPresetID == preset.id, let dragStartIndex else { return }
                dragOffset = value.translation.height
                let indexOffset = Int((dragOffset / editRowStride).rounded())
                dragTargetIndex = min(
                    max(0, dragStartIndex + indexOffset),
                    reorderablePresets.count - 1
                )
            }
            .onEnded { _ in
                if !isDragCancelled, draggedPresetID == preset.id {
                    commitDrag(of: preset)
                }
                resetDrag()
            }
    }

    private func beginDrag(of preset: TimerPreset) {
        draggedPresetID = preset.id
        dragStartIndex = reorderablePresets.firstIndex(where: { $0.id == preset.id })
        dragTargetIndex = dragStartIndex
        monitorEscapeKey()
    }

    private func commitDrag(of preset: TimerPreset) {
        guard let dragTargetIndex, reorderablePresets.indices.contains(dragTargetIndex) else { return }
        // Taking the target preset's place puts the dragged one before it when moving up and after
        // it when moving down, wherever the stopwatch sits in the array.
        let targetID = reorderablePresets[dragTargetIndex].id
        guard let storeIndex = presetsStore.presets.firstIndex(where: { $0.id == targetID }) else { return }
        presetsStore.movePreset(preset.id, toIndex: storeIndex)
    }

    /// How far a row is shifted while a drag is in progress: the dragged row follows the pointer,
    /// and the rows between its start and target slide one place to make room.
    private func rowOffset(for preset: TimerPreset) -> CGFloat {
        guard let draggedPresetID, let dragStartIndex, let dragTargetIndex,
              let rowIndex = reorderablePresets.firstIndex(where: { $0.id == preset.id }) else {
            return 0
        }

        if preset.id == draggedPresetID {
            return dragOffset
        }
        if dragTargetIndex > dragStartIndex,
           rowIndex > dragStartIndex,
           rowIndex <= dragTargetIndex {
            return -editRowStride
        }
        if dragTargetIndex < dragStartIndex,
           rowIndex >= dragTargetIndex,
           rowIndex < dragStartIndex {
            return editRowStride
        }
        return 0
    }

    private func monitorEscapeKey() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == Self.escapeKeyCode else { return event }
            DispatchQueue.main.async {
                cancelDrag()
            }
            return nil
        }
    }

    private func cancelDrag() {
        clearDragState()
        isDragCancelled = true
    }

    private func resetDrag() {
        clearDragState()
        isDragCancelled = false
    }

    private func clearDragState() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        draggedPresetID = nil
        dragStartIndex = nil
        dragTargetIndex = nil
        dragOffset = 0
    }
}

/// Edit-mode row for a timer group: its name and an editable line per timer.
private struct TimerGroupEditor: View {
    @ObservedObject var groupsStore: TimerGroupsStore
    let group: TimerGroup

    /// The store's current copy of the group; `group` may be stale between edits.
    private var currentGroup: TimerGroup? {
        groupsStore.groups.first(where: { $0.id == group.id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                TextField("Group name", text: nameBinding)
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
    }

    private func timerRow(for timer: TimerPreset) -> some View {
        HStack(spacing: 5) {
            Picker("Type", selection: binding(for: timer, \.type)) {
                Image(systemName: "arrow.up").imageScale(.small).tag(TimerType.countUp)
                Image(systemName: "arrow.down").imageScale(.small).tag(TimerType.countdown)
            }
            .labelsHidden()
            .frame(width: 45)
            TextField("Timer name", text: binding(for: timer, \.name))
            if timer.type == .countdown {
                DurationPicker(duration: binding(for: timer, \.seconds))
            }
            RemoveButton { groupsStore.removeTimer(timer, from: group) }
                .disabled(group.timers.count == 1)
        }
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

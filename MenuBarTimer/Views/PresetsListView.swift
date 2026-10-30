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

    /// The presets that are listed (and can be reordered) above the stopwatch. Drag indices refer
    /// to this list, not to `presetsStore.presets`, which also contains the stopwatch somewhere.
    private var reorderablePresets: [TimerPreset] {
        presetsStore.presets.filter { !$0.isStopwatch }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            .anchorPreference(key: PresetsHeaderBoundsKey.self, value: .bounds) { $0 }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(reorderablePresets) { preset in
                        row(for: preset)
                    }
                    if isEditing {
                        Button {
                            presetsStore.addPreset()
                        } label: {
                            Label("Add Single Timer", systemImage: "plus.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .padding(.top, 4)
                    }

                    if let stopwatch = presetsStore.presets.first(where: { $0.isStopwatch }) {
                        Text("Stopwatch")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        row(for: stopwatch)
                    }

                    if !groupsStore.groups.isEmpty {
                        Text("Timer Groups")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                        ForEach(groupsStore.groups) { group in
                            groupRow(for: group)
                        }
                    }

                    if isEditing {
                        Button {
                            groupsStore.addGroup()
                            presetsStore.clearSelection()
                            groupCoordinator.load(groupsStore.selectedGroup)
                        } label: {
                            Label("Add Timer Group", systemImage: "rectangle.3.group")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.purple)
                        .padding(.top, 4)
                    }
                }
                // The scroll view clips to its bounds, which would cut off the rows' focus rings.
                // Inset the content by the ring's width and widen the scroll view by the same amount.
                .padding(Self.focusRingInset)
            }
            .padding(-Self.focusRingInset)
        }
        .padding(24)
        .frame(width: 280)
        .onDisappear { resetDrag() }
        // The Edit button is the initially focused control whenever the window opens.
        .onAppear { DispatchQueue.main.async { isEditButtonFocused = true } }
        .onReceive(NotificationCenter.default.publisher(for: MainWindowController.didShowNotification)) { _ in
            DispatchQueue.main.async { isEditButtonFocused = true }
        }
    }

    private func groupRow(for group: TimerGroup) -> some View {
        let isSelected = groupsStore.selectedGroupID == group.id
        return Group {
            if isEditing {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        TextField("Group name", text: groupNameBinding(for: group))
                        Button { groupsStore.remove(group) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }.buttonStyle(.plain)
                    }
                    ForEach(group.timers) { timer in
                        HStack(spacing: 5) {
                            Picker("Type", selection: timerTypeBinding(timer, in: group)) {
                                Image(systemName: "arrow.up").imageScale(.small).tag(TimerType.countUp)
                                Image(systemName: "arrow.down").imageScale(.small).tag(TimerType.countdown)
                            }.labelsHidden().frame(width: 45)
                            TextField("Timer name", text: timerNameBinding(timer, in: group))
                            if timer.type == .countdown {
                                DurationPicker(duration: timerDurationBinding(timer, in: group))
                            }
                            Button {
                                groupsStore.removeTimer(timer, from: group)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(group.timers.count == 1)
                        }
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
            } else {
                Button {
                    groupsStore.select(group)
                    presetsStore.clearSelection()
                    groupCoordinator.load(group)
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
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? .purple : nil)
            }
        }
    }

    @ViewBuilder
    private func row(for preset: TimerPreset) -> some View {
        if isEditing {
            HStack(spacing: 8) {
                if !preset.isStopwatch {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 24)
                        .contentShape(Rectangle())
                        .help("Drag to rearrange preset")
                        .gesture(reorderGesture(for: preset))
                    DurationPicker(duration: durationBinding(for: preset))
                    Button(action: {presetsStore.removePreset(preset)}) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("Stopwatch", systemImage: "stopwatch")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .offset(y: rowOffset(for: preset))
            .opacity(draggedPresetID == preset.id ? 0.65 : 1)
            .zIndex(draggedPresetID == preset.id ? 1 : 0)
            .animation(
                preset.id == draggedPresetID ? nil : .easeOut(duration: 0.1),
                value: dragTargetIndex
            )
        } else {
            let isSelected = presetsStore.selectedPresetID == preset.id
            Button {
                presetsStore.select(preset)
                groupsStore.clearSelection()
                groupCoordinator.load(nil)
                timerModel.load(preset)
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
    }

    private func reorderGesture(for preset: TimerPreset) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                guard !isDragCancelled else { return }
                if draggedPresetID == nil {
                    draggedPresetID = preset.id
                    dragStartIndex = reorderablePresets.firstIndex(where: { $0.id == preset.id })
                    dragTargetIndex = dragStartIndex
                    monitorEscapeKey()
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
                if !isDragCancelled,
                   draggedPresetID == preset.id,
                   let dragTargetIndex,
                   reorderablePresets.indices.contains(dragTargetIndex),
                   // Taking the target preset's place puts the dragged one before it when moving
                   // up and after it when moving down, wherever the stopwatch sits in the array.
                   let storeIndex = presetsStore.presets.firstIndex(where: { $0.id == reorderablePresets[dragTargetIndex].id }) {
                    presetsStore.movePreset(preset.id, toIndex: storeIndex)
                }
                resetDrag()
            }
    }

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

    private func groupNameBinding(for group: TimerGroup) -> Binding<String> {
        Binding(get: { groupsStore.groups.first(where: { $0.id == group.id })?.name ?? "" }, set: { value in
            guard var current = groupsStore.groups.first(where: { $0.id == group.id }) else { return }
            current.name = value; groupsStore.update(current)
        })
    }

    private func timerNameBinding(_ timer: TimerPreset, in group: TimerGroup) -> Binding<String> {
        groupBinding(timer, in: group, keyPath: \.name)
    }

    private func timerTypeBinding(_ timer: TimerPreset, in group: TimerGroup) -> Binding<TimerType> {
        groupBinding(timer, in: group, keyPath: \.type)
    }

    private func timerDurationBinding(_ timer: TimerPreset, in group: TimerGroup) -> Binding<TimeInterval> {
        groupBinding(timer, in: group, keyPath: \.seconds)
    }

    private func groupBinding<Value>(_ timer: TimerPreset, in group: TimerGroup, keyPath: WritableKeyPath<TimerPreset, Value>) -> Binding<Value> {
        Binding(get: {
            groupsStore.groups.first(where: { $0.id == group.id })?.timers.first(where: { $0.id == timer.id }).map { $0[keyPath: keyPath] } ?? timer[keyPath: keyPath]
        }, set: { value in
            guard var current = groupsStore.groups.first(where: { $0.id == group.id }),
                  let index = current.timers.firstIndex(where: { $0.id == timer.id }) else { return }
            current.timers[index][keyPath: keyPath] = value
            groupsStore.update(current)
        })
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
}

#Preview {
    PresetsListView(timerModel: TimerModel(), presetsStore: PresetsStore(), groupsStore: TimerGroupsStore(), groupCoordinator: TimerGroupCoordinator())
}

//
//  TimerGroupEditor.swift
//  MenuBarTimer
//

import SwiftUI

/// Edit-mode row for a timer group: its name and an editable line per timer.
struct TimerGroupEditor: View {
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
                groupsStore.updateGroup(id: group.id) { $0.name = newName }
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
                groupsStore.updateGroup(id: group.id) { group in
                    guard let index = group.timers.firstIndex(where: { $0.id == timer.id }) else { return }
                    group.timers[index][keyPath: keyPath] = newValue
                }
            }
        )
    }
}

/// The red minus button that deletes a preset, group or group timer in edit mode.
struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }
}

//
//  PresetsListView.swift
//  MenuBarTimer
//

import SwiftUI

/// The right-hand side of the overlay: quick-start presets and the app menu.
struct PresetsListView: View {
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var presetsStore: PresetsStore
    @State private var isEditing = false
    @State private var draggedPresetID: UUID?
    @State private var dragStartIndex: Int?
    @State private var dragTargetIndex: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var escapeMonitor: Any?
    @State private var isDragCancelled = false

    private let editRowStride: CGFloat = 32

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
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Menu {
                    Button("Quit MenuBarTimer") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
                .frame(width: 22)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(presetsStore.presets) { preset in
                        row(for: preset)
                    }

                    if isEditing {
                        Button {
                            presetsStore.addPreset()
                        } label: {
                            Label("Add Preset", systemImage: "plus.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 280)
        .onDisappear { resetDrag() }
    }

    @ViewBuilder
    private func row(for preset: TimerPreset) -> some View {
        if isEditing {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 24)
                    .contentShape(Rectangle())
                    .help("Drag to rearrange preset")
                    .gesture(reorderGesture(for: preset))

                DurationPicker(duration: durationBinding(for: preset))

                Button {
                    presetsStore.removePreset(preset)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
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
                timerModel.load(seconds: preset.seconds)
            } label: {
                HStack {
                    Text(preset.seconds.formattedClock)
                        .monospacedDigit()
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
                    dragStartIndex = presetsStore.presets.firstIndex(where: { $0.id == preset.id })
                    dragTargetIndex = dragStartIndex
                    monitorEscapeKey()
                }

                guard draggedPresetID == preset.id, let dragStartIndex else { return }
                dragOffset = value.translation.height
                let indexOffset = Int((dragOffset / editRowStride).rounded())
                dragTargetIndex = min(
                    max(0, dragStartIndex + indexOffset),
                    presetsStore.presets.count - 1
                )
            }
            .onEnded { _ in
                if !isDragCancelled,
                   draggedPresetID == preset.id,
                   let dragTargetIndex {
                    presetsStore.movePreset(preset.id, toIndex: dragTargetIndex)
                }
                resetDrag()
            }
    }

    private func rowOffset(for preset: TimerPreset) -> CGFloat {
        guard let draggedPresetID, let dragStartIndex, let dragTargetIndex,
              let rowIndex = presetsStore.presets.firstIndex(where: { $0.id == preset.id }) else {
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
            guard event.keyCode == 53 else { return event }
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
    PresetsListView(timerModel: TimerModel(), presetsStore: PresetsStore())
}

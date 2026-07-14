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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Presets")
                    .font(.headline)

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
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
        .frame(width: 220)
    }

    @ViewBuilder
    private func row(for preset: TimerPreset) -> some View {
        if isEditing {
            HStack {
                Stepper(value: minutesBinding(for: preset), in: 1...180) {
                    Text(preset.seconds.formattedClock)
                        .monospacedDigit()
                }

                Button {
                    presetsStore.removePreset(preset)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
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

    private func minutesBinding(for preset: TimerPreset) -> Binding<Int> {
        Binding<Int>(
            get: { preset.minutes },
            set: { newValue in
                guard let index = presetsStore.presets.firstIndex(where: { $0.id == preset.id }) else { return }
                presetsStore.presets[index].minutes = newValue
            }
        )
    }
}

#Preview {
    PresetsListView(timerModel: TimerModel(), presetsStore: PresetsStore())
}

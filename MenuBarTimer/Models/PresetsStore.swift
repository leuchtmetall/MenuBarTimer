//
//  PresetsStore.swift
//  MenuBarTimer
//

import Combine
import Foundation
import SwiftUI

/// Persists the user's list of quick-start timer presets, along with which one is currently selected.
final class PresetsStore: ObservableObject {
    @Published var presets: [TimerPreset] {
        didSet { savePresets() }
    }

    @Published var selectedPresetID: UUID? {
        didSet { saveSelectedPresetID() }
    }

    private static let presetsKey = "presets"
    private static let selectedPresetKey = "selectedPresetID"
    static let selectedKindKey = "selectedTimerKind"

    /// Index into `defaultPresets` used as the selection on a fresh install.
    private static let defaultSelectedIndex = 3

    private static let defaultPresets: [TimerPreset] = [5, 10, 15, 25, 45].map {
        TimerPreset(seconds: TimeInterval($0 * 60))
    } + [.stopwatch]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.presetsKey),
           let decoded = try? JSONDecoder().decode([TimerPreset].self, from: data),
           !decoded.isEmpty {
            presets = decoded.contains(where: { $0.isStopwatch }) ? decoded : decoded + [.stopwatch]
        } else {
            presets = Self.defaultPresets
        }

        let selectedKind = UserDefaults.standard.string(forKey: Self.selectedKindKey)
        if selectedKind == "group" {
            selectedPresetID = nil
        } else if let idString = UserDefaults.standard.string(forKey: Self.selectedPresetKey),
           let uuid = UUID(uuidString: idString),
           presets.contains(where: { $0.id == uuid }) {
            selectedPresetID = uuid
        } else {
            selectedPresetID = presets.indices.contains(Self.defaultSelectedIndex)
                ? presets[Self.defaultSelectedIndex].id
                : presets.first?.id
        }
        savePresets()
    }

    var selectedPreset: TimerPreset? {
        presets.first { $0.id == selectedPresetID }
    }

    func select(_ preset: TimerPreset) {
        selectedPresetID = preset.id
        UserDefaults.standard.set("preset", forKey: Self.selectedKindKey)
    }

    func clearSelection() {
        selectedPresetID = nil
    }

    func addPreset(seconds: TimeInterval = 5 * 60) {
        presets.append(TimerPreset(seconds: seconds))
    }

    func removePreset(_ preset: TimerPreset) {
        presets.removeAll { $0.id == preset.id }
        if selectedPresetID == preset.id {
            selectedPresetID = presets.first?.id
        }
    }

    func movePreset(_ presetID: UUID, toIndex targetIndex: Int) {
        guard let sourceIndex = presets.firstIndex(where: { $0.id == presetID }),
              presets.indices.contains(targetIndex),
              sourceIndex != targetIndex else {
            return
        }

        let preset = presets.remove(at: sourceIndex)
        presets.insert(preset, at: targetIndex)
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: Self.presetsKey)
    }

    private func saveSelectedPresetID() {
        if let id = selectedPresetID {
            UserDefaults.standard.set(id.uuidString, forKey: Self.selectedPresetKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedPresetKey)
        }
    }
}

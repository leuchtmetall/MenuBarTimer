//
//  PresetsStore.swift
//  MenuBarTimer
//

import Combine
import Foundation
import SwiftUI

/// Which of the two mutually exclusive modes is active: a standalone preset or a timer group.
/// Shared by `PresetsStore` and `TimerGroupsStore`, which each own one side of the selection.
enum SelectedTimerKind: String {
    case preset
    case group

    private static let userDefaultsKey = "selectedTimerKind"

    static func load(from userDefaults: UserDefaults) -> SelectedTimerKind? {
        userDefaults.string(forKey: userDefaultsKey).flatMap(SelectedTimerKind.init(rawValue:))
    }

    static func clear(in userDefaults: UserDefaults) {
        userDefaults.removeObject(forKey: userDefaultsKey)
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(rawValue, forKey: Self.userDefaultsKey)
    }
}

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
    private let userDefaults: UserDefaults

    /// Index into `defaultPresets` used as the selection on a fresh install.
    private static let defaultSelectedIndex = 3

    private static let defaultPresets: [TimerPreset] = [5, 10, 15, 25, 45].map {
        TimerPreset(seconds: TimeInterval($0 * 60))
    } + [.stopwatch]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.presetsKey),
           let decoded = try? JSONDecoder().decode([TimerPreset].self, from: data),
           !decoded.isEmpty {
            presets = decoded.contains(where: { $0.isStopwatch }) ? decoded : decoded + [.stopwatch]
        } else {
            presets = Self.defaultPresets
        }

        if SelectedTimerKind.load(from: userDefaults) == .group {
            selectedPresetID = nil
        } else if let idString = userDefaults.string(forKey: Self.selectedPresetKey),
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
        SelectedTimerKind.preset.save(to: userDefaults)
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
        userDefaults.set(data, forKey: Self.presetsKey)
    }

    private func saveSelectedPresetID() {
        if let id = selectedPresetID {
            userDefaults.set(id.uuidString, forKey: Self.selectedPresetKey)
        } else {
            userDefaults.removeObject(forKey: Self.selectedPresetKey)
        }
    }
}

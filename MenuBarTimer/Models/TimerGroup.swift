//
//  TimerGroup.swift
//  MenuBarTimer
//

import Combine
import Foundation
import SwiftUI

struct TimerGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var timers: [TimerPreset]

    init(id: UUID = UUID(), name: String = "Timer Group", timers: [TimerPreset]) {
        self.id = id
        self.name = name
        self.timers = timers
    }

    static var example: TimerGroup {
        TimerGroup(name: "Focus", timers: [
            TimerPreset(seconds: 25 * 60, name: "Work", colorName: "blue"),
            TimerPreset(seconds: 5 * 60, name: "Break", colorName: "green")
        ])
    }
}

final class TimerGroupsStore: ObservableObject {
    @Published var groups: [TimerGroup] {
        didSet { save() }
    }
    @Published var selectedGroupID: UUID? {
        didSet { saveSelection() }
    }

    private static let groupsKey = "timerGroups"
    private static let selectionKey = "selectedTimerGroupID"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.groupsKey),
           let decoded = try? JSONDecoder().decode([TimerGroup].self, from: data) {
            groups = decoded.filter { $0.name != "Stopwatch" }
        } else {
            groups = []
        }
        let selectedKind = SelectedTimerKind.load(from: userDefaults)
        if selectedKind == .preset {
            selectedGroupID = nil
        } else if selectedKind == .group, groups.isEmpty {
            selectedGroupID = nil
            SelectedTimerKind.clear(in: userDefaults)
        } else if let value = userDefaults.string(forKey: Self.selectionKey),
           let id = UUID(uuidString: value), groups.contains(where: { $0.id == id }) {
            selectedGroupID = id
            if selectedKind == nil { SelectedTimerKind.group.save(to: userDefaults) }
        } else if selectedKind == nil, let firstGroup = groups.first {
            selectedGroupID = firstGroup.id
            SelectedTimerKind.group.save(to: userDefaults)
        } else {
            selectedGroupID = nil
        }
        save()
    }

    var selectedGroup: TimerGroup? { groups.first { $0.id == selectedGroupID } }

    func addGroup() {
        let group = TimerGroup.example
        groups.append(group)
        select(group)
    }

    func select(_ group: TimerGroup) {
        selectedGroupID = group.id
        SelectedTimerKind.group.save(to: userDefaults)
    }

    func clearSelection() {
        selectedGroupID = nil
    }

    func remove(_ group: TimerGroup) {
        groups.removeAll { $0.id == group.id }
        group.timers.forEach(removeSavedState)
        if selectedGroupID == group.id {
            selectedGroupID = groups.first?.id
            if selectedGroupID == nil { SelectedTimerKind.clear(in: userDefaults) }
        }
    }

    func update(_ group: TimerGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index] = group
    }

    func addTimer(to group: TimerGroup) {
        guard var current = groups.first(where: { $0.id == group.id }) else { return }
        let colors = TimerPreset.newTimerColorNames
        current.timers.append(TimerPreset(
            seconds: 5 * 60,
            name: "Timer \(current.timers.count + 1)",
            colorName: colors[current.timers.count % colors.count]
        ))
        update(current)
    }

    func removeTimer(_ timer: TimerPreset, from group: TimerGroup) {
        guard var current = groups.first(where: { $0.id == group.id }), current.timers.count > 1 else { return }
        current.timers.removeAll { $0.id == timer.id }
        update(current)
        removeSavedState(of: timer)
    }

    /// Deletes the progress `TimerGroupModel` persisted for a timer that no longer exists.
    private func removeSavedState(of timer: TimerPreset) {
        userDefaults.removeObject(forKey: TimerGroupModel.savedStateKey(for: timer))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        userDefaults.set(data, forKey: Self.groupsKey)
    }

    private func saveSelection() {
        if let selectedGroupID { userDefaults.set(selectedGroupID.uuidString, forKey: Self.selectionKey) }
        else { userDefaults.removeObject(forKey: Self.selectionKey) }
    }
}

/// Coordinates the timers in one group. Starting one always pauses every other timer.
final class TimerGroupCoordinator: ObservableObject {
    @Published private(set) var model: TimerGroupModel?
    private var modelCancellable: AnyCancellable?

    func load(_ group: TimerGroup?) {
        guard let group else {
            model = nil
            modelCancellable = nil
            return
        }
        let currentTimerIDs = model?.group.timers.map { $0.id }
        let newTimerIDs = group.timers.map { $0.id }
        if let model, model.group.id == group.id, currentTimerIDs == newTimerIDs {
            model.updateDefinition(group)
        } else {
            let newModel = TimerGroupModel(group: group)
            model = newModel
            modelCancellable = newModel.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
    }
}

final class TimerGroupModel: ObservableObject {
    @Published private(set) var group: TimerGroup
    @Published private(set) var timerModels: [TimerModel]
    @Published var activeTimerID: UUID?
    private var timerCancellables = Set<AnyCancellable>()

    init(group: TimerGroup, userDefaults: UserDefaults = .standard) {
        self.group = group
        self.timerModels = group.timers.map {
            TimerModel(userDefaults: userDefaults, savedStateKey: Self.savedStateKey(for: $0))
        }
        self.activeTimerID = group.timers.first?.id
        for (index, definition) in group.timers.enumerated() {
            let timer = timerModels[index]
            // The group may have been edited while it wasn't loaded, leaving the saved state stale.
            if !timer.hasLoadedTimer || timer.preset.type != definition.type || timer.preset.seconds != definition.seconds {
                timer.load(definition)
            } else {
                timer.updateDisplayDetails(from: definition)
            }
        }
        observeTimers()
    }

    static func savedStateKey(for timer: TimerPreset) -> String {
        "timerGroupState-\(timer.id.uuidString)"
    }

    private func observeTimers() {
        timerModels.forEach { timer in
            timer.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &timerCancellables)
        }
    }

    func updateDefinition(_ group: TimerGroup) {
        guard group.id == self.group.id, group.timers.count == timerModels.count else { return }

        for (index, definition) in group.timers.enumerated() {
            let previous = self.group.timers[index]
            if previous.type != definition.type || previous.seconds != definition.seconds {
                timerModels[index].load(definition)
            } else {
                // Name/color edits must reach the timer model too: the menu bar label reads them from there.
                timerModels[index].updateDisplayDetails(from: definition)
            }
        }
        self.group = group
    }

    func start(_ definition: TimerPreset) {
        guard let index = group.timers.firstIndex(where: { $0.id == definition.id }) else { return }
        for (otherIndex, timer) in timerModels.enumerated() where otherIndex != index { timer.pause() }
        activeTimerID = definition.id
        timerModels[index].primaryButtonTapped()
    }

    func pauseAll() { timerModels.forEach { $0.pause() } }

    /// `true` when every timer is idle, i.e. none has been started, paused or finished since its last reset.
    var isInInitialState: Bool { timerModels.allSatisfy { $0.state == .idle } }

    /// Stops every timer, resetting each back to its loaded duration.
    func resetAll() {
        timerModels.forEach { $0.stop() }
        activeTimerID = group.timers.first?.id
    }
}

//
//  TimerGroup.swift
//  MenuBarTimer
//

import Combine
import Foundation
import SwiftUI

/// A named timer inside a group. Timers may independently count up or down.
struct GroupTimer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var seconds: TimeInterval
    var type: TimerType
    /// A SwiftUI color name, kept as data so groups remain Codable.
    var colorName: String

    init(id: UUID = UUID(), name: String, seconds: TimeInterval, type: TimerType = .countdown, colorName: String = "blue") {
        self.id = id
        self.name = name
        self.seconds = seconds
        self.type = type
        self.colorName = colorName
    }

    var color: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }
}

struct TimerGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var timers: [GroupTimer]

    init(id: UUID = UUID(), name: String = "Timer Group", timers: [GroupTimer]) {
        self.id = id
        self.name = name
        self.timers = timers
    }

    static var example: TimerGroup {
        TimerGroup(name: "Focus", timers: [
            GroupTimer(name: "Work", seconds: 25 * 60, colorName: "blue"),
            GroupTimer(name: "Break", seconds: 5 * 60, colorName: "green")
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

    private let groupsKey = "timerGroups"
    private let selectionKey = "selectedTimerGroupID"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: groupsKey),
           let decoded = try? JSONDecoder().decode([TimerGroup].self, from: data) {
            groups = decoded.filter { $0.name != "Stopwatch" }
        } else {
            groups = []
        }
        let selectedKind = userDefaults.string(forKey: PresetsStore.selectedKindKey)
        if selectedKind == "preset" {
            selectedGroupID = nil
        } else if selectedKind == "group", groups.isEmpty {
            selectedGroupID = nil
            userDefaults.removeObject(forKey: PresetsStore.selectedKindKey)
        } else if let value = userDefaults.string(forKey: selectionKey),
           let id = UUID(uuidString: value), groups.contains(where: { $0.id == id }) {
            selectedGroupID = id
            if selectedKind == nil { userDefaults.set("group", forKey: PresetsStore.selectedKindKey) }
        } else if selectedKind == nil, let firstGroup = groups.first {
            selectedGroupID = firstGroup.id
            userDefaults.set("group", forKey: PresetsStore.selectedKindKey)
        } else {
            selectedGroupID = nil
        }
        save()
    }

    private let userDefaults: UserDefaults



    var selectedGroup: TimerGroup? { groups.first { $0.id == selectedGroupID } }

    func addGroup() {
        let group = TimerGroup.example
        groups.append(group)
        selectedGroupID = group.id
        userDefaults.set("group", forKey: PresetsStore.selectedKindKey)
    }

    func select(_ group: TimerGroup) {
        selectedGroupID = group.id
        userDefaults.set("group", forKey: PresetsStore.selectedKindKey)
    }

    func clearSelection() {
        selectedGroupID = nil
    }

    func remove(_ group: TimerGroup) {
        groups.removeAll { $0.id == group.id }
        if selectedGroupID == group.id {
            selectedGroupID = groups.first?.id
            if selectedGroupID == nil { userDefaults.removeObject(forKey: PresetsStore.selectedKindKey) }
        }
    }

    func update(_ group: TimerGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index] = group
    }

    func addTimer(to group: TimerGroup) {
        guard var current = groups.first(where: { $0.id == group.id }) else { return }
        let colors = ["blue", "green", "orange", "purple", "red", "pink"]
        current.timers.append(GroupTimer(
            name: "Timer \(current.timers.count + 1)",
            seconds: 5 * 60,
            colorName: colors[current.timers.count % colors.count]
        ))
        update(current)
    }

    func removeTimer(_ timer: GroupTimer, from group: TimerGroup) {
        guard var current = groups.first(where: { $0.id == group.id }), current.timers.count > 1 else { return }
        current.timers.removeAll { $0.id == timer.id }
        update(current)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        userDefaults.set(data, forKey: groupsKey)
    }

    private func saveSelection() {
        if let selectedGroupID { userDefaults.set(selectedGroupID.uuidString, forKey: selectionKey) }
        else { userDefaults.removeObject(forKey: selectionKey) }
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
    @Published private(set) var timers: [TimerModel]
    @Published var activeTimerID: UUID?
    private var timerCancellables = Set<AnyCancellable>()

    init(group: TimerGroup, userDefaults: UserDefaults = .standard) {
        self.group = group
        self.timers = group.timers.map {
            TimerModel(userDefaults: userDefaults, savedStateKey: "timerGroupState-\($0.id.uuidString)")
        }
        self.activeTimerID = group.timers.first?.id
        for (index, definition) in group.timers.enumerated() {
            let timer = timers[index]
            if timer.timerType != definition.type || !timer.hasLoadedTimer {
                timer.load(type: definition.type, duration: definition.type == .countUp ? 0 : definition.seconds)
            }
        }
        observeTimers()
    }

    private func observeTimers() {
        timers.forEach { timer in
            timer.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &timerCancellables)
        }
    }

    var activeTimer: TimerModel? {
        guard let activeTimerID, let index = group.timers.firstIndex(where: { $0.id == activeTimerID }) else { return nil }
        return timers[index]
    }

    func updateDefinition(_ group: TimerGroup) {
        guard group.id == self.group.id, group.timers.count == timers.count else { return }

        for (index, definition) in group.timers.enumerated() {
            let previous = self.group.timers[index]
            if previous.type != definition.type || previous.seconds != definition.seconds {
                timers[index].load(
                    type: definition.type,
                    duration: definition.type == .countUp ? 0 : definition.seconds
                )
            }
        }
        self.group = group
    }

    func select(_ definition: GroupTimer) { activeTimerID = definition.id }

    func start(_ definition: GroupTimer) {
        guard let index = group.timers.firstIndex(where: { $0.id == definition.id }) else { return }
        for (otherIndex, timer) in timers.enumerated() where otherIndex != index { timer.pause() }
        activeTimerID = definition.id
        timers[index].primaryButtonTapped()
    }

    func pauseAll() { timers.forEach { $0.pause() } }
}

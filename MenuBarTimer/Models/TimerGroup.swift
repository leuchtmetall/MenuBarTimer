//
//  TimerGroup.swift
//  MenuBarTimer
//

import Combine
import Foundation

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
        userDefaults.removeObject(forKey: TimerGroupModel.activeTimerKey(for: group))
        if selectedGroupID == group.id {
            selectedGroupID = groups.first?.id
            if selectedGroupID == nil { SelectedTimerKind.clear(in: userDefaults) }
        }
    }

    /// Inserts a copy of the group right after it. The copy and its timers get fresh IDs, so they
    /// have their own saved progress (`TimerGroupModel.savedStateKey`) and don't share the original's.
    func duplicate(_ group: TimerGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        let original = groups[index] // the store's current copy; `group` may be stale
        let copy = TimerGroup(
            name: original.name + " Copy",
            timers: original.timers.map {
                TimerPreset(seconds: $0.seconds, type: $0.type, name: $0.name, colorName: $0.colorName)
            }
        )
        groups.insert(copy, at: index + 1)
    }

    /// Edits the store's current copy of the group with `id`, which is what callers holding a
    /// possibly stale `TimerGroup` value need. Returns whether anything changed; a group that no
    /// longer exists, or an edit that leaves it as it was, publishes and saves nothing.
    @discardableResult
    func updateGroup(id: UUID, _ edit: (inout TimerGroup) -> Void) -> Bool {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        var group = groups[index]
        edit(&group)
        guard group != groups[index] else { return false }
        groups[index] = group
        return true
    }

    func addTimer(to group: TimerGroup) {
        updateGroup(id: group.id) { group in
            let colors = TimerPreset.newTimerColorNames
            group.timers.append(TimerPreset(
                seconds: 5 * 60,
                name: "Timer \(group.timers.count + 1)",
                colorName: colors[group.timers.count % colors.count]
            ))
        }
    }

    /// Moves a timer within its group so that it ends up at `targetIndex`.
    func moveTimer(_ timerID: UUID, in group: TimerGroup, toIndex targetIndex: Int) {
        updateGroup(id: group.id) { group in
            guard let sourceIndex = group.timers.firstIndex(where: { $0.id == timerID }),
                  group.timers.indices.contains(targetIndex) else { return }
            group.timers.insert(group.timers.remove(at: sourceIndex), at: targetIndex)
        }
    }

    /// Removes a timer from its group, unless it is the group's last one.
    func removeTimer(_ timer: TimerPreset, from group: TimerGroup) {
        let wasRemoved = updateGroup(id: group.id) { group in
            guard group.timers.count > 1 else { return }
            group.timers.removeAll { $0.id == timer.id }
        }
        if wasRemoved { removeSavedState(of: timer) }
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
        // An edit of the loaded group is applied in place, so its timers keep running. Another group,
        // or one whose timers were added or removed, gets a fresh model.
        if let model, model.updateDefinition(group) { return }
        let newModel = TimerGroupModel(group: group)
        model = newModel
        modelCancellable = newModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

final class TimerGroupModel: ObservableObject {
    @Published private(set) var group: TimerGroup
    @Published private(set) var timerModels: [TimerModel]
    /// The running timer, or the one that ran most recently. Persisted so compact mode shows the same
    /// timer after a relaunch.
    @Published var activeTimerID: UUID? {
        didSet { saveActiveTimer() }
    }
    private var timerCancellables = Set<AnyCancellable>()
    private let userDefaults: UserDefaults

    init(group: TimerGroup, userDefaults: UserDefaults = .standard) {
        self.group = group
        self.userDefaults = userDefaults
        self.timerModels = group.timers.map {
            TimerModel(userDefaults: userDefaults, savedStateKey: Self.savedStateKey(for: $0))
        }
        if let value = userDefaults.string(forKey: Self.activeTimerKey(for: group)),
           let id = UUID(uuidString: value), group.timers.contains(where: { $0.id == id }) {
            self.activeTimerID = id
        } else {
            self.activeTimerID = group.timers.first?.id
        }
        // The group may have been edited while it wasn't loaded, leaving the saved state stale.
        for (definition, timer) in zip(group.timers, timerModels) { timer.apply(definition) }
        observeTimers()
    }

    static func savedStateKey(for timer: TimerPreset) -> String {
        "timerGroupState-\(timer.id.uuidString)"
    }

    static func activeTimerKey(for group: TimerGroup) -> String {
        "timerGroupActiveTimer-\(group.id.uuidString)"
    }

    private func saveActiveTimer() {
        let key = Self.activeTimerKey(for: group)
        if let activeTimerID { userDefaults.set(activeTimerID.uuidString, forKey: key) }
        else { userDefaults.removeObject(forKey: key) }
    }

    private func observeTimers() {
        timerModels.forEach { timer in
            timer.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &timerCancellables)
        }
    }

    /// Applies an edited definition of the same group. The timers may have been reordered, but must be
    /// the same set; each keeps its running state unless its type or duration changed.
    /// Returns `false`, changing nothing, for another group or another set of timers.
    @discardableResult
    func updateDefinition(_ group: TimerGroup) -> Bool {
        let modelsByID = Dictionary(uniqueKeysWithValues: zip(self.group.timers.map(\.id), timerModels))
        let reorderedModels = group.timers.compactMap { modelsByID[$0.id] }
        guard group.id == self.group.id, group.timers.count == timerModels.count,
              reorderedModels.count == timerModels.count else { return false }

        // Name and color edits must reach the timer models too: the views read them from there.
        for (definition, timer) in zip(group.timers, reorderedModels) { timer.apply(definition) }
        if !reorderedModels.elementsEqual(timerModels, by: ===) { timerModels = reorderedModels }
        self.group = group
        return true
    }

    func start(_ definition: TimerPreset) {
        guard let timer = timerModels.first(where: { $0.preset.id == definition.id }) else { return }
        for other in timerModels where other !== timer { other.pause() }
        activeTimerID = definition.id
        timer.primaryButtonTapped()
    }

    /// `true` when every timer is idle, i.e. none has been started, paused or finished since its last reset.
    var isInInitialState: Bool { timerModels.allSatisfy { $0.state == .idle } }

    /// Stops every timer, resetting each back to its loaded duration.
    func resetAll() {
        timerModels.forEach { $0.stop() }
        activeTimerID = group.timers.first?.id
    }
}

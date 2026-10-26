//
//  MenuBarTimerTests.swift
//  MenuBarTimerTests
//
//  Created by Leonhard Massloch on 2026/07/14.
//

import CoreGraphics
import Foundation
import Testing
@testable import MenuBarTimer

struct MenuBarTimerTests {
    @Test func timerPositionIsRestored() {
        let defaults = UserDefaults(suiteName: "TimerModelTests")!
        defaults.removePersistentDomain(forName: "TimerModelTests")

        let timer = TimerModel(userDefaults: defaults)
        timer.load(TimerPreset(seconds: 100))
        timer.start()
        timer.setProgress(0.4)
        timer.pause()

        let restoredTimer = TimerModel(userDefaults: defaults)

        #expect(restoredTimer.totalDuration == 100)
        // Pausing captures the exact moment, so the few microseconds since `setProgress` count too.
        #expect(abs(restoredTimer.remaining - 60) < 0.5)
        #expect(restoredTimer.state == .paused)

        defaults.removePersistentDomain(forName: "TimerModelTests")
    }

    @Test func stoppedTimerCanBeAdjustedAndUndone() {
        let defaults = UserDefaults(suiteName: "StoppedTimerAdjustmentTests")!
        defaults.removePersistentDomain(forName: "StoppedTimerAdjustmentTests")
        var notifiedPresets: [TimerPreset] = []
        let timer = TimerModel(userDefaults: defaults) { notifiedPresets.append($0) }
        timer.load(TimerPreset(seconds: 100))

        timer.setProgress(0.25)
        #expect(timer.remaining == 75)
        #expect(timer.state == .paused)
        #expect(timer.canUndoAdjustment)

        timer.setProgress(1)
        #expect(timer.remaining == 0)
        #expect(timer.state == .finished)
        #expect(notifiedPresets.isEmpty)

        timer.undoAdjustment()
        #expect(timer.remaining == 100)
        #expect(timer.state == .idle)
        #expect(!timer.canUndoAdjustment)

        timer.setProgress(0.5)
        timer.resume()
        #expect(timer.state == .running)
        #expect(timer.remaining == 50)
        #expect(!timer.canUndoAdjustment)

        defaults.removePersistentDomain(forName: "StoppedTimerAdjustmentTests")
    }

    @Test func timerGroupOnlyRunsOneTimerAtATime() {
        let defaults = UserDefaults(suiteName: "TimerGroupTests")!
        defaults.removePersistentDomain(forName: "TimerGroupTests")
        let first = TimerPreset(seconds: 60, name: "Work")
        let second = TimerPreset(seconds: 30, type: .countUp, name: "Break")
        let group = TimerGroup(name: "Focus", timers: [first, second])
        let model = TimerGroupModel(group: group, userDefaults: defaults)

        model.start(first)
        #expect(model.timerModels[0].state == .running)
        #expect(model.timerModels[1].state != .running)

        model.start(second)
        #expect(model.timerModels[0].state == .paused)
        #expect(model.timerModels[1].state == .running)

        defaults.removePersistentDomain(forName: "TimerGroupTests")
    }

    @Test func resettingAllGroupTimersReturnsToInitialState() {
        let defaults = UserDefaults(suiteName: "TimerGroupResetAllTests")!
        defaults.removePersistentDomain(forName: "TimerGroupResetAllTests")
        let first = TimerPreset(seconds: 60, name: "First", colorName: "blue")
        let second = TimerPreset(seconds: 120, name: "Second", colorName: "green")
        let model = TimerGroupModel(group: TimerGroup(timers: [first, second]), userDefaults: defaults)
        #expect(model.isInInitialState)

        model.start(first)
        model.start(second)
        #expect(!model.isInInitialState)

        model.resetAll()
        #expect(model.isInInitialState)
        #expect(model.timerModels[0].remaining == 60)
        #expect(model.timerModels[1].remaining == 120)
        #expect(model.activeTimerID == first.id)

        defaults.removePersistentDomain(forName: "TimerGroupResetAllTests")
    }

    @Test func renamingGroupTimerUpdatesTimerModelWithoutResetting() {
        let defaults = UserDefaults(suiteName: "TimerGroupRenameTests")!
        defaults.removePersistentDomain(forName: "TimerGroupRenameTests")
        let timer = TimerPreset(seconds: 60, name: "Work", colorName: "blue")
        var group = TimerGroup(name: "Focus", timers: [timer])
        let model = TimerGroupModel(group: group, userDefaults: defaults)
        model.start(timer)

        group.timers[0].name = "Deep Work"
        group.timers[0].colorName = "red"
        model.updateDefinition(group)

        #expect(model.timerModels[0].preset.name == "Deep Work")
        #expect(model.timerModels[0].preset.colorName == "red")
        #expect(model.timerModels[0].state == .running)

        defaults.removePersistentDomain(forName: "TimerGroupRenameTests")
    }

    @Test func stopwatchCountsUpAndResets() {
        let defaults = UserDefaults(suiteName: "StopwatchTests")!
        defaults.removePersistentDomain(forName: "StopwatchTests")

        let timer = TimerModel(userDefaults: defaults)
        timer.load(.stopwatch)
        timer.start()
        timer.pause()

        #expect(timer.preset.type == .countUp)
        #expect(timer.totalDuration == 0)
        #expect(timer.remaining >= 0)
        #expect(timer.state == .paused)

        timer.stop()
        #expect(timer.remaining == 0)
        #expect(timer.state == .idle)

        defaults.removePersistentDomain(forName: "StopwatchTests")
    }

    @Test func timerFinishNotificationFollowsSetting() {
        let defaults = UserDefaults(suiteName: "TimerFinishNotificationTests")!
        defaults.removePersistentDomain(forName: "TimerFinishNotificationTests")
        let settings = AppSettings(userDefaults: defaults)
        var notifiedPresets: [TimerPreset] = []
        let preset = TimerPreset(seconds: 60)
        let timer = TimerModel(userDefaults: defaults) { notifiedPresets.append($0) }

        #expect(settings.showTimerFinishNotification)

        timer.load(preset)
        timer.start()
        timer.setProgress(1)

        #expect(notifiedPresets == [preset])

        settings.showTimerFinishNotification = false
        timer.primaryButtonTapped()
        timer.setProgress(1)

        #expect(notifiedPresets == [preset])

        defaults.removePersistentDomain(forName: "TimerFinishNotificationTests")
    }

    @Test func compactColoredLabelsSettingIsPersisted() {
        let defaults = UserDefaults(suiteName: "CompactColoredLabelsTests")!
        defaults.removePersistentDomain(forName: "CompactColoredLabelsTests")

        #expect(AppSettings(userDefaults: defaults).useCompactColoredLabels == false)

        AppSettings(userDefaults: defaults).useCompactColoredLabels = true
        #expect(AppSettings(userDefaults: defaults).useCompactColoredLabels)

        defaults.removePersistentDomain(forName: "CompactColoredLabelsTests")
    }

    @Test func groupLabelHitTestFindsTimerUnderCursor() {
        let ids = [UUID(), UUID(), UUID()]
        // 100pt of content centered in a 120pt wide status item, so the content starts at x = 10.
        let layout = makeLayout(ids: ids, widths: [40, 30, 30], contentWidth: 100)

        #expect(layout.timerID(atX: 11, boundsWidth: 120) == ids[0])
        #expect(layout.timerID(atX: 49, boundsWidth: 120) == ids[0])
        #expect(layout.timerID(atX: 51, boundsWidth: 120) == ids[1])
        #expect(layout.timerID(atX: 79, boundsWidth: 120) == ids[1])
        #expect(layout.timerID(atX: 81, boundsWidth: 120) == ids[2])
    }

    @Test func groupLabelHitTestClampsToNearestTimer() {
        let ids = [UUID(), UUID()]
        let layout = makeLayout(ids: ids, widths: [50, 50], contentWidth: 100)

        // Clicks in the status item's edge padding still act on the closest timer.
        #expect(layout.timerID(atX: 0, boundsWidth: 120) == ids[0])
        #expect(layout.timerID(atX: -5, boundsWidth: 120) == ids[0])
        #expect(layout.timerID(atX: 120, boundsWidth: 120) == ids[1])
    }

    @Test func groupLabelHitTestNormalizesMeasuredWidths() {
        let ids = [UUID(), UUID()]
        // Measured segments sum to 50 but the laid out label is 100 wide, so the boundary belongs
        // at 50 rather than at the measured 20.
        let layout = makeLayout(ids: ids, widths: [20, 30], contentWidth: 100)

        #expect(layout.timerID(atX: 39, boundsWidth: 100) == ids[0])
        #expect(layout.timerID(atX: 41, boundsWidth: 100) == ids[1])
    }

    @Test func groupLabelHitTestUsesDrawnContentFrame() {
        let ids = [UUID(), UUID()]
        // Measured 372pt wide (e.g. with the wrong font), but the button draws the label 300pt wide
        // starting at x = 10. The segments must follow what is drawn, not the measurement.
        let layout = makeLayout(ids: ids, widths: [186, 186], contentWidth: 372)
        let drawn = CGRect(x: 10, y: 0, width: 300, height: 16)

        #expect(layout.timerID(atX: 159, boundsWidth: 320, contentFrame: drawn) == ids[0])
        #expect(layout.timerID(atX: 161, boundsWidth: 320, contentFrame: drawn) == ids[1])
        #expect(layout.hit(atX: 200, boundsWidth: 320, contentFrame: drawn)
            == MenuBarLabelLayout.Hit(timerID: ids[1], minX: 160, width: 150))
        // Edge padding still clamps to the nearest timer.
        #expect(layout.timerID(atX: 2, boundsWidth: 320, contentFrame: drawn) == ids[0])
        #expect(layout.timerID(atX: 318, boundsWidth: 320, contentFrame: drawn) == ids[1])
    }

    @Test func rightClickIsLocatedOnTheDisplayUnderTheCursor() {
        // Values from a real two-display setup: the status item window sits 1029pt from the right
        // edge of both displays' menu bars.
        let main = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let laptop = CGRect(x: 196, y: -982, width: 1512, height: 982)
        let onMain = CGRect(x: 1214, y: 1407, width: 317, height: 33)
        let onLaptop = CGRect(x: 362, y: -33, width: 317, height: 33)

        // Window and cursor on the same display.
        #expect(RightClickHandlerView.windowX(ofScreenX: 1259, windowFrame: onMain,
                                              windowScreenFrame: main, mouseScreenFrame: main) == 45)
        // The window is still on the laptop display while the click happened on the main one.
        #expect(RightClickHandlerView.windowX(ofScreenX: 1259, windowFrame: onLaptop,
                                              windowScreenFrame: laptop, mouseScreenFrame: main) == 45)
        #expect(RightClickHandlerView.windowX(ofScreenX: 407, windowFrame: onMain,
                                              windowScreenFrame: main, mouseScreenFrame: laptop) == 45)
    }

    @Test func groupLabelHitTestHandlesDegenerateGroups() {
        #expect(MenuBarLabelLayout().timerID(atX: 20, boundsWidth: 120) == nil)

        let id = UUID()
        let single = makeLayout(ids: [id], widths: [40], contentWidth: 40)
        #expect(single.timerID(atX: 0, boundsWidth: 120) == id)
        #expect(single.timerID(atX: 119, boundsWidth: 120) == id)

        single.clear()
        #expect(single.timerID(atX: 60, boundsWidth: 120) == nil)
    }

    @Test func groupLabelSegmentsSplitTheGapsBetweenTimers() {
        let ids = [UUID(), UUID(), UUID()]
        let segments = MenuBarLabelLayout.distribute(ids: ids, widths: [10, 10, 10], gap: 4, leadingInset: 2)

        // The 4pt gaps are shared evenly, so the segments tile the label without dead zones.
        #expect(segments.map(\.width) == [14, 14, 12])
        let totalWidth: CGFloat = segments.reduce(0) { $0 + $1.width }
        #expect(totalWidth == 40) // leading inset + 3 timers + 2 gaps
        // A widths/ids mismatch would misattribute clicks, so it yields no segments at all.
        #expect(MenuBarLabelLayout.distribute(ids: ids, widths: [10, 10], gap: 4).isEmpty)
    }

    @MainActor @Test func pausingACountdownKeepsTheTimeElapsedSinceTheLastTick() async throws {
        let defaults = UserDefaults(suiteName: "CountdownPauseTests")!
        defaults.removePersistentDomain(forName: "CountdownPauseTests")
        let timer = TimerModel(userDefaults: defaults)
        timer.load(TimerPreset(seconds: 100))

        timer.start()
        try await Task.sleep(for: .milliseconds(300))
        timer.pause()

        // Without catching up on pause, `remaining` would still read 100 (no tick has fired yet).
        #expect(timer.remaining < 99.8)
        #expect(timer.state == .paused)

        defaults.removePersistentDomain(forName: "CountdownPauseTests")
    }

    @Test func groupEditedWhileUnloadedIsAppliedOnLoad() {
        let defaults = UserDefaults(suiteName: "TimerGroupStaleDefinitionTests")!
        defaults.removePersistentDomain(forName: "TimerGroupStaleDefinitionTests")
        let timer = TimerPreset(seconds: 60, name: "Work", colorName: "blue")
        var group = TimerGroup(name: "Focus", timers: [timer])
        _ = TimerGroupModel(group: group, userDefaults: defaults)

        // Edited in the presets list while another group (or a preset) was selected.
        group.timers[0].seconds = 120
        group.timers[0].name = "Deep Work"
        let reloaded = TimerGroupModel(group: group, userDefaults: defaults)

        #expect(reloaded.timerModels[0].totalDuration == 120)
        #expect(reloaded.timerModels[0].preset.name == "Deep Work")

        defaults.removePersistentDomain(forName: "TimerGroupStaleDefinitionTests")
    }

    @Test func removingGroupTimersDeletesTheirSavedState() {
        let defaults = UserDefaults(suiteName: "TimerGroupSavedStateCleanupTests")!
        defaults.removePersistentDomain(forName: "TimerGroupSavedStateCleanupTests")
        let store = TimerGroupsStore(userDefaults: defaults)
        store.addGroup()
        let group = store.groups[0]
        _ = TimerGroupModel(group: group, userDefaults: defaults)
        let keys = group.timers.map { TimerGroupModel.savedStateKey(for: $0) }
        #expect(keys.allSatisfy { defaults.data(forKey: $0) != nil })

        store.removeTimer(group.timers[0], from: group)
        #expect(defaults.data(forKey: keys[0]) == nil)
        #expect(defaults.data(forKey: keys[1]) != nil)

        store.remove(store.groups[0])
        #expect(defaults.data(forKey: keys[1]) == nil)

        defaults.removePersistentDomain(forName: "TimerGroupSavedStateCleanupTests")
    }

    @Test func selectedModeIsRestoredForBothStores() {
        let defaults = UserDefaults(suiteName: "SelectedTimerKindTests")!
        defaults.removePersistentDomain(forName: "SelectedTimerKindTests")
        let presets = PresetsStore(userDefaults: defaults)
        let groups = TimerGroupsStore(userDefaults: defaults)
        groups.addGroup()
        presets.clearSelection()

        #expect(PresetsStore(userDefaults: defaults).selectedPresetID == nil)
        #expect(TimerGroupsStore(userDefaults: defaults).selectedGroupID == groups.selectedGroupID)

        let preset = presets.presets[0]
        presets.select(preset)
        groups.clearSelection()

        #expect(PresetsStore(userDefaults: defaults).selectedPresetID == preset.id)
        #expect(TimerGroupsStore(userDefaults: defaults).selectedGroupID == nil)

        defaults.removePersistentDomain(forName: "SelectedTimerKindTests")
    }

    private func makeLayout(ids: [UUID], widths: [CGFloat], contentWidth: CGFloat) -> MenuBarLabelLayout {
        let layout = MenuBarLabelLayout()
        layout.update(
            segments: ids.indices.map { MenuBarLabelLayout.Segment(timerID: ids[$0], width: widths[$0]) },
            contentWidth: contentWidth
        )
        return layout
    }
}

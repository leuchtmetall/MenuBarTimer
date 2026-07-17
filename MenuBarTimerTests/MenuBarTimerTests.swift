//
//  MenuBarTimerTests.swift
//  MenuBarTimerTests
//
//  Created by Leonhard Massloch on 2026/07/14.
//

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
        #expect(restoredTimer.remaining == 60)
        #expect(restoredTimer.state == .paused)

        defaults.removePersistentDomain(forName: "TimerModelTests")
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
}

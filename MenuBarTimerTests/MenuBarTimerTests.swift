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
        timer.load(seconds: 100)
        timer.start()
        timer.setProgress(0.4)
        timer.pause()

        let restoredTimer = TimerModel(userDefaults: defaults)

        #expect(restoredTimer.totalDuration == 100)
        #expect(restoredTimer.remaining == 60)
        #expect(restoredTimer.state == .paused)

        defaults.removePersistentDomain(forName: "TimerModelTests")
    }
}

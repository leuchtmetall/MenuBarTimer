//
//  SwipeToDismissTrackerTests.swift
//  MenuBarTimerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MenuBarTimer

struct SwipeToDismissTrackerTests {
    private typealias Sample = SwipeToDismissTracker.Sample

    /// Feeds a gesture of `steps` equal moves of (`dx`, `dy`) spaced `interval` seconds apart,
    /// followed by an `.ended` sample, and returns every action.
    private func swipe(
        _ tracker: inout SwipeToDismissTracker,
        dx: CGFloat, dy: CGFloat = 0, steps: Int, interval: TimeInterval = 0.016, start: TimeInterval = 0
    ) -> [SwipeToDismissTracker.Action] {
        var actions: [SwipeToDismissTracker.Action] = []
        for step in 0..<steps {
            let phase: SwipeToDismissTracker.Phase = step == 0 ? .began : .changed
            actions.append(tracker.handle(Sample(phase: phase, dx: dx, dy: dy, timestamp: start + Double(step) * interval)))
        }
        actions.append(tracker.handle(Sample(phase: .ended, dx: 0, dy: 0, timestamp: start + Double(steps) * interval)))
        return actions
    }

    @Test func longRightwardSwipeDismisses() {
        var tracker = SwipeToDismissTracker()
        // 20 × 6 pt = 120 pt, slowly.
        let actions = swipe(&tracker, dx: 6, steps: 20, interval: 0.1)
        #expect(actions.contains(.track(offset: 60)))
        guard case .dismiss = actions.last else {
            Issue.record("expected dismiss, got \(String(describing: actions.last))")
            return
        }
    }

    @Test func shortSlowSwipeRestores() {
        var tracker = SwipeToDismissTracker()
        let actions = swipe(&tracker, dx: 4, steps: 10, interval: 0.1)
        #expect(actions.last == .restore)
    }

    @Test func shortFastFlickDismisses() {
        var tracker = SwipeToDismissTracker()
        // 5 × 8 pt = 40 pt in 80 ms ≈ 500–2500 pt/s.
        let actions = swipe(&tracker, dx: 8, steps: 5, interval: 0.004)
        guard case .dismiss = actions.last else {
            Issue.record("expected dismiss, got \(String(describing: actions.last))")
            return
        }
    }

    @Test func verticalSwipePassesThrough() {
        var tracker = SwipeToDismissTracker()
        let actions = swipe(&tracker, dx: 1, dy: 10, steps: 20)
        #expect(actions.allSatisfy { $0 == .passThrough })
        // Its momentum keeps scrolling too.
        #expect(tracker.handle(Sample(phase: .momentum, dx: 0, dy: 10, timestamp: 1)) == .passThrough)
    }

    @Test func leftwardSwipePassesThrough() {
        var tracker = SwipeToDismissTracker()
        let actions = swipe(&tracker, dx: -10, steps: 20)
        #expect(actions.allSatisfy { $0 == .passThrough })
    }

    @Test func offsetNeverGoesLeftOfStart() {
        var tracker = SwipeToDismissTracker()
        _ = tracker.handle(Sample(phase: .began, dx: 10, dy: 0, timestamp: 0))
        #expect(tracker.handle(Sample(phase: .changed, dx: -30, dy: 0, timestamp: 0.1)) == .track(offset: 0))
    }

    @Test func momentumAfterSwipeIsIgnored() {
        var tracker = SwipeToDismissTracker()
        _ = swipe(&tracker, dx: 6, steps: 20, interval: 0.1)
        #expect(tracker.handle(Sample(phase: .momentum, dx: 20, dy: 0, timestamp: 3)) == .ignore)
    }

    @Test func cancelledSwipeRestores() {
        var tracker = SwipeToDismissTracker()
        _ = tracker.handle(Sample(phase: .began, dx: 10, dy: 0, timestamp: 0))
        #expect(tracker.handle(Sample(phase: .cancelled, dx: 0, dy: 0, timestamp: 0.1)) == .restore)
    }

    @Test func newGestureResetsState() {
        var tracker = SwipeToDismissTracker()
        _ = swipe(&tracker, dx: 6, steps: 20, interval: 0.1)
        let actions = swipe(&tracker, dx: 0, dy: 10, steps: 5, start: 5)
        #expect(actions.allSatisfy { $0 == .passThrough })
    }

    @Test func tinyGestureBelowLockDistancePassesThrough() {
        var tracker = SwipeToDismissTracker()
        let actions = swipe(&tracker, dx: 1, steps: 3)
        #expect(actions.allSatisfy { $0 == .passThrough })
    }
}

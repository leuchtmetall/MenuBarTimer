//
//  SwipeToDismissTracker.swift
//  MenuBarTimer
//

import AppKit

/// Recognizes a two-finger swipe to the right from trackpad scroll events, like the one that dismisses
/// a notification. Decides only; `MainPanel` moves the window.
///
/// A gesture is locked to one axis after a few points of movement. Vertical (and leftward) gestures
/// are passed through untouched so scroll views keep working; a rightward one is consumed for its
/// whole duration, including the momentum events that follow it.
nonisolated struct SwipeToDismissTracker {
    enum Phase {
        case began, changed, ended, cancelled
        /// Inertial scrolling after the fingers left the trackpad.
        case momentum
    }

    /// One scroll event. `dx`/`dy` are finger movement in points, positive `dx` meaning right.
    struct Sample {
        var phase: Phase
        var dx: CGFloat
        var dy: CGFloat
        var timestamp: TimeInterval
    }

    enum Action: Equatable {
        /// Not part of a swipe; deliver the event as usual.
        case passThrough
        /// Part of a swipe; the window should be shifted right by `offset`.
        case track(offset: CGFloat)
        /// The swipe ended far or fast enough; the window should be dismissed.
        case dismiss(velocity: CGFloat)
        /// The swipe ended short; the window should return to where it was.
        case restore
        /// Part of a finished swipe (momentum); swallow the event.
        case ignore
    }

    /// Movement after which a gesture is locked to an axis.
    static let axisLockDistance: CGFloat = 6
    /// Releasing at or beyond this offset dismisses.
    static let dismissDistance: CGFloat = 90
    /// Releasing faster than this (points per second) dismisses, if the window moved at all.
    static let flickVelocity: CGFloat = 700
    static let flickMinimumDistance: CGFloat = 15

    private enum State {
        case idle, undecided, tracking, passingThrough, finished
    }

    private var state: State = .idle
    private var totalDX: CGFloat = 0
    private var totalDY: CGFloat = 0
    /// Recent samples used to estimate the release velocity.
    private var recent: [(dx: CGFloat, timestamp: TimeInterval)] = []

    private var offset: CGFloat { max(0, totalDX) }

    mutating func handle(_ sample: Sample) -> Action {
        if sample.phase == .began {
            state = .undecided
            totalDX = 0
            totalDY = 0
            recent = []
        }

        switch state {
        case .idle, .passingThrough:
            return .passThrough
        case .finished:
            return .ignore
        case .undecided, .tracking:
            // Momentum only follows an ended gesture, so this doesn't happen in practice.
            if sample.phase == .momentum { return .passThrough }
        }

        totalDX += sample.dx
        totalDY += sample.dy
        recent.append((sample.dx, sample.timestamp))
        recent.removeAll { sample.timestamp - $0.timestamp > 0.1 }

        if state == .undecided {
            if hypot(totalDX, totalDY) >= Self.axisLockDistance {
                state = totalDX > 0 && abs(totalDX) > 1.5 * abs(totalDY) ? .tracking : .passingThrough
            } else if sample.phase == .ended || sample.phase == .cancelled {
                state = .idle
                return .passThrough
            }
            if state != .tracking { return .passThrough }
        }

        switch sample.phase {
        case .began, .changed, .momentum:
            return .track(offset: offset)
        case .cancelled:
            state = .finished
            return .restore
        case .ended:
            state = .finished
            let velocity = releaseVelocity(at: sample.timestamp)
            if offset >= Self.dismissDistance || (velocity > Self.flickVelocity && offset > Self.flickMinimumDistance) {
                return .dismiss(velocity: velocity)
            }
            return .restore
        }
    }

    private func releaseVelocity(at timestamp: TimeInterval) -> CGFloat {
        guard let first = recent.first else { return 0 }
        let duration = timestamp - first.timestamp
        guard duration > 0.001 else { return 0 }
        return recent.map(\.dx).reduce(0, +) / duration
    }
}

nonisolated extension SwipeToDismissTracker.Sample {
    /// Converts a trackpad scroll event. Returns nil for events that can't be part of a swipe, such as
    /// those from wheel mice.
    init?(_ event: NSEvent) {
        guard event.type == .scrollWheel, event.hasPreciseScrollingDeltas else { return nil }
        let phase: SwipeToDismissTracker.Phase
        switch event.phase {
        case [] where !event.momentumPhase.isEmpty: phase = .momentum
        case .began: phase = .began
        case .changed: phase = .changed
        case .ended: phase = .ended
        case .cancelled: phase = .cancelled
        default: return nil
        }
        // With natural scrolling the deltas follow the fingers; otherwise they are inverted.
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        self.init(phase: phase, dx: sign * event.scrollingDeltaX, dy: sign * event.scrollingDeltaY, timestamp: event.timestamp)
    }
}

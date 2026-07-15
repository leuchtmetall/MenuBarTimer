//
//  TimerModel.swift
//  MenuBarTimer
//

import Combine
import Foundation

/// Drives a single countdown timer.
final class TimerModel: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var canUndoAdjustment = false

    private static let adjustmentUndoDuration: TimeInterval = 10
    private var timer: Timer?
    private var undoTimer: Timer?
    private var endDate: Date?
    private var adjustmentOriginalEndDate: Date?

    /// Fraction of the timer that has elapsed, from `0` (just started) to `1` (finished).
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(1 - remaining / totalDuration, 0), 1)
    }

    /// Loads a duration into the timer without starting the countdown.
    func load(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        clearAdjustmentUndo()
        invalidateTimer()
        endDate = nil
        totalDuration = seconds
        remaining = seconds
        state = .idle
    }

    /// Starts counting down from the current `remaining` value.
    func start() {
        guard remaining > 0 else { return }
        clearAdjustmentUndo()
        invalidateTimer()
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        scheduleTimer()
    }

    /// Toggles between running and paused, or restarts after finishing.
    func primaryButtonTapped() {
        switch state {
        case .idle:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        case .finished:
            remaining = totalDuration
            start()
        }
    }

    func pause() {
        guard state == .running else { return }
        clearAdjustmentUndo()
        invalidateTimer()
        endDate = nil
        state = .paused
    }

    func resume() {
        guard state == .paused, remaining > 0 else { return }
        clearAdjustmentUndo()
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        scheduleTimer()
    }

    /// Stops the timer and resets the remaining time back to the loaded duration.
    func stop() {
        clearAdjustmentUndo()
        invalidateTimer()
        endDate = nil
        remaining = totalDuration
        state = .idle
    }

    /// Moves a running timer to a position on its progress ring.
    /// The position represents elapsed time, so `0` is the start and `1` is the end.
    func setProgress(_ progress: Double) {
        guard state == .running, totalDuration > 0 else { return }

        if adjustmentOriginalEndDate == nil {
            adjustmentOriginalEndDate = endDate
        }

        let clampedProgress = min(max(progress, 0), 1)
        let newRemaining = totalDuration * (1 - clampedProgress)
        remaining = newRemaining
        endDate = Date().addingTimeInterval(newRemaining)
        canUndoAdjustment = true
        scheduleAdjustmentUndoExpiry()

        if newRemaining <= 0 {
            finish()
        }
    }

    /// Restores the timer's original countdown deadline, including time elapsed since the drag.
    func undoAdjustment() {
        guard let originalEndDate = adjustmentOriginalEndDate, canUndoAdjustment else { return }

        let restoredRemaining = originalEndDate.timeIntervalSinceNow
        if restoredRemaining <= 0 {
            remaining = 0
            finish()
            return
        }

        invalidateTimer()
        remaining = restoredRemaining
        endDate = originalEndDate
        state = .running
        clearAdjustmentUndo()
        scheduleTimer()
    }

    private func scheduleTimer() {
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            // The timer is added to RunLoop.main below, so this always fires on the main thread.
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleAdjustmentUndoExpiry() {
        undoTimer?.invalidate()
        let newTimer = Timer(timeInterval: Self.adjustmentUndoDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clearAdjustmentUndo()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        undoTimer = newTimer
    }

    private func clearAdjustmentUndo() {
        undoTimer?.invalidate()
        undoTimer = nil
        adjustmentOriginalEndDate = nil
        canUndoAdjustment = false
    }

    private func tick() {
        guard let endDate else { return }
        let newRemaining = endDate.timeIntervalSinceNow
        if newRemaining <= 0 {
            remaining = 0
            finish()
        } else {
            remaining = newRemaining
        }
    }

    private func finish() {
        clearAdjustmentUndo()
        invalidateTimer()
        endDate = nil
        state = .finished
        SoundPlayer.playTimerCompleteSound()
    }
}

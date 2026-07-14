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

    private var timer: Timer?
    private var endDate: Date?

    /// Fraction of the timer that has elapsed, from `0` (just started) to `1` (finished).
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(1 - remaining / totalDuration, 0), 1)
    }

    /// Loads a duration into the timer without starting the countdown.
    func load(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        invalidateTimer()
        endDate = nil
        totalDuration = seconds
        remaining = seconds
        state = .idle
    }

    /// Starts counting down from the current `remaining` value.
    func start() {
        guard remaining > 0 else { return }
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
        invalidateTimer()
        endDate = nil
        state = .paused
    }

    func resume() {
        guard state == .paused, remaining > 0 else { return }
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        scheduleTimer()
    }

    /// Stops the timer and resets the remaining time back to the loaded duration.
    func stop() {
        invalidateTimer()
        endDate = nil
        remaining = totalDuration
        state = .idle
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
        invalidateTimer()
        endDate = nil
        state = .finished
        SoundPlayer.playTimerCompleteSound()
    }
}

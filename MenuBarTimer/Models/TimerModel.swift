//
//  TimerModel.swift
//  MenuBarTimer
//

import AppKit
import Combine
import Foundation

/// Drives a single countdown or count-up timer.
final class TimerModel: Identifiable, ObservableObject {
    let id: UUID
    enum State: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    @Published private(set) var preset: TimerPreset = TimerPreset(seconds: 5*60)
    @Published private(set) var state: State = .idle
    @Published private(set) var totalDuration: TimeInterval = 0 // TODO get from preset
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var canUndoAdjustment = false

    private static let adjustmentUndoDuration: TimeInterval = 10
    private static let defaultSavedStateKey = "timerState"

    private struct SavedState: Codable {
        let preset: TimerPreset
        let totalDuration: TimeInterval
        let remaining: TimeInterval
        let state: StateValue
    }

    private enum StateValue: String, Codable {
        case idle
        case running
        case paused
        case finished
    }

    private let userDefaults: UserDefaults
    private let savedStateKey: String
    private let onFinish: (TimerPreset) -> Void
    private var terminationObserver: NSObjectProtocol?
    private var timer: Timer?
    private var undoTimer: Timer?
    private var endDate: Date?
    private var startDate: Date?
    private var adjustmentOriginalEndDate: Date?

    init(
        id: UUID = UUID(),
        userDefaults: UserDefaults = .standard,
        savedStateKey: String = TimerModel.defaultSavedStateKey,
        onFinish: @escaping (TimerPreset) -> Void = TimerCompletionNotifier.send
    ) {
        self.id = id
        self.userDefaults = userDefaults
        self.savedStateKey = savedStateKey
        self.onFinish = onFinish
        restoreState()
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveState()
        }
    }

    deinit {
        invalidateTimer()
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    var hasLoadedTimer: Bool {
        preset.type == .countUp || totalDuration > 0
    }

    /// Fraction of the timer that has elapsed, from `0` (just started) to `1` (finished).
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(1 - remaining / totalDuration, 0), 1)
    }
    
    var timeString: String {
        preset.type == .countUp
            ? remaining.formattedElapsedClock
            : remaining.formattedClock
    }

    /// Loads a preset without starting the timer.
    func load(_ timerPreset: TimerPreset) {
        clearAdjustmentUndo()
        invalidateTimer()
        endDate = nil
        startDate = nil
        preset = timerPreset
        totalDuration = timerPreset.seconds
        remaining = timerPreset.seconds
        state = .idle
        saveState()
    }

    /// Starts the timer from its current position.
    func start() {
        guard preset.type == .countUp || remaining > 0 else { return }
        clearAdjustmentUndo()
        invalidateTimer()
        if preset.type == .countUp {
            startDate = Date().addingTimeInterval(-remaining)
        } else {
            endDate = Date().addingTimeInterval(remaining)
        }
        state = .running
        scheduleTimer()
        saveState()
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
        if preset.type == .countUp {
            tick()
        }
        invalidateTimer()
        endDate = nil
        state = .paused
        saveState()
    }

    func resume() {
        guard state == .paused, preset.type == .countUp || remaining > 0 else { return }
        clearAdjustmentUndo()
        if preset.type == .countUp {
            startDate = Date().addingTimeInterval(-remaining)
        } else {
            endDate = Date().addingTimeInterval(remaining)
        }
        state = .running
        scheduleTimer()
        saveState()
    }

    /// Stops the timer and resets the remaining time back to the loaded duration.
    func stop() {
        clearAdjustmentUndo()
        invalidateTimer()
        endDate = nil
        startDate = nil
        remaining = preset.type == .countUp ? 0 : totalDuration
        state = .idle
        saveState()
    }

    /// Moves a running timer to a position on its progress ring.
    /// The position represents elapsed time, so `0` is the start and `1` is the end.
    func setProgress(_ progress: Double) {
        guard preset.type == .countdown, state == .running, totalDuration > 0 else { return }

        if adjustmentOriginalEndDate == nil {
            adjustmentOriginalEndDate = endDate
        }

        let clampedProgress = min(max(progress, 0), 1)
        let newRemaining = totalDuration * (1 - clampedProgress)
        remaining = newRemaining
        endDate = Date().addingTimeInterval(newRemaining)
        canUndoAdjustment = true
        scheduleAdjustmentUndoExpiry()
        saveState()

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

    private func restoreState() {
        guard let data = userDefaults.data(forKey: savedStateKey),
              let savedState = try? JSONDecoder().decode(SavedState.self, from: data),
              savedState.totalDuration >= 0,
              savedState.remaining >= 0 else { return }

        preset = savedState.preset
        totalDuration = savedState.totalDuration
        remaining = savedState.preset.type == .countUp ? savedState.remaining : min(savedState.remaining, savedState.totalDuration)
        switch savedState.state {
        case .idle: state = .idle
        case .running, .paused: state = .paused
        case .finished: state = .finished
        }
    }

    private func saveState() {
        var savedRemaining = remaining
        if state == .running {
            if preset.type == .countUp, let startDate {
                savedRemaining = max(Date().timeIntervalSince(startDate), 0)
            } else if let endDate {
                savedRemaining = max(endDate.timeIntervalSinceNow, 0)
            }
        }

        let savedState = SavedState(
            preset: preset,
            totalDuration: totalDuration,
            remaining: savedRemaining,
            state: stateValue
        )
        guard let data = try? JSONEncoder().encode(savedState) else { return }
        userDefaults.set(data, forKey: savedStateKey)
    }

    private var stateValue: StateValue {
        switch state {
        case .idle: return .idle
        case .running: return .running
        case .paused: return .paused
        case .finished: return .finished
        }
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
        if preset.type == .countUp {
            guard let startDate else { return }
            remaining = max(Date().timeIntervalSince(startDate), 0)
            return
        }

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
        saveState()
        SoundPlayer.playTimerCompleteSound()
        if AppSettings.timerFinishNotificationsEnabled(in: userDefaults) {
            onFinish(preset)
        }
    }
}

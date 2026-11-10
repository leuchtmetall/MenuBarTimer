//
//  TimerPreset.swift
//  MenuBarTimer
//

import Foundation
import SwiftUI

/// The kind of timer a preset starts.
nonisolated enum TimerType: String, Codable, Equatable {
    case countdown
    case countUp
}

/// A user-configurable, quick-start timer preset.
nonisolated struct TimerPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var seconds: TimeInterval
    var type: TimerType
    // group timer specific
    var name: String
    var colorName: String?

    init(id: UUID = UUID(), seconds: TimeInterval, type: TimerType = .countdown, name: String? = nil, colorName: String? = nil) {
        self.id = id
        self.seconds = seconds
        self.type = type
        self.name = name ?? ""
        self.colorName = colorName
    }
    
    /// The timer's color (see `TimerColor`), or `.primary` when it has none.
    var color: Color { TimerColor.color(named: colorName) ?? .primary }

    /// The colors new group timers cycle through, in order. All of them are `TimerColor` palette names.
    static let newTimerColorNames = ["blue", "green", "orange", "purple", "red", "pink"]

    static var stopwatch: TimerPreset {
        TimerPreset(seconds: 0, type: .countUp)
    }

    var isStopwatch: Bool {
        type == .countUp
    }
}

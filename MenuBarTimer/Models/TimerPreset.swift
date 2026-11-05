//
//  TimerPreset.swift
//  MenuBarTimer
//

import Foundation
import SwiftUI

/// The kind of timer a preset starts.
enum TimerType: String, Codable, Equatable {
    case countdown
    case countUp
}

/// A user-configurable, quick-start timer preset.
struct TimerPreset: Identifiable, Codable, Equatable {
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
    
    var color: Color { Self.color(named: colorName) }

    /// The color for a `colorName`; unknown names and `nil` give the default `.primary`.
    static func color(named colorName: String?) -> Color {
        switch colorName {
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .primary
        }
    }

    /// Every color name `color` handles, in the order the group editor's color picker offers them.
    static let colorNames = ["blue", "green", "yellow", "orange", "red", "pink", "purple"]

    /// The colors new group timers cycle through, in order. All of them are handled by `color`.
    static let newTimerColorNames = ["blue", "green", "orange", "purple", "red", "pink"]

    static var stopwatch: TimerPreset {
        TimerPreset(seconds: 0, type: .countUp)
    }

    var isStopwatch: Bool {
        type == .countUp
    }

    var hours: Int {
        get { Int(seconds) / 3600 }
        set { updateComponent(hours: newValue, minutes: minutesComponent, seconds: secondsComponent) }
    }

    /// The minutes component of the duration, excluding complete hours.
    var minutesComponent: Int {
        get { (Int(seconds) % 3600) / 60 }
        set { updateComponent(hours: hours, minutes: newValue, seconds: secondsComponent) }
    }

    /// The seconds component of the duration, excluding complete minutes.
    var secondsComponent: Int {
        get { Int(seconds) % 60 }
        set { updateComponent(hours: hours, minutes: minutesComponent, seconds: newValue) }
    }

    private mutating func updateComponent(hours: Int, minutes: Int, seconds: Int) {
        self.seconds = TimeInterval((hours * 3600) + (minutes * 60) + seconds)
    }
}

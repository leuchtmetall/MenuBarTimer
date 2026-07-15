//
//  TimerPreset.swift
//  MenuBarTimer
//

import Foundation

/// A user-configurable, quick-start timer duration.
struct TimerPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var seconds: TimeInterval

    init(id: UUID = UUID(), seconds: TimeInterval) {
        self.id = id
        self.seconds = seconds
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

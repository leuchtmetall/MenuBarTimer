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

    var minutes: Int {
        get { Int(seconds / 60) }
        set { seconds = TimeInterval(newValue * 60) }
    }
}

//
//  TimeInterval+Formatting.swift
//  MenuBarTimer
//

import Foundation

extension TimeInterval {
    /// Formats the interval as `mm:ss`, or `h:mm:ss` if the interval is an hour or longer.
    var formattedClock: String {
        let total = Int(self.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

//
//  AppSettings.swift
//  MenuBarTimer
//

import Combine
import Foundation

enum GroupTimerNameDisplay: String, CaseIterable, Identifiable {
    case wholeLabel
    case firstCharacter
    case none

    var id: Self { self }

    var title: String {
        switch self {
        case .wholeLabel: return "Full name"
        case .firstCharacter: return "First letter"
        case .none: return "Hidden"
        }
    }
}

/// User preferences for the menu bar timer.
final class AppSettings: ObservableObject {
    @Published var groupTimerNameDisplay: GroupTimerNameDisplay {
        didSet { userDefaults.set(groupTimerNameDisplay.rawValue, forKey: Self.nameDisplayKey) }
    }
    @Published var showGroupTimerProgress: Bool {
        didSet { userDefaults.set(showGroupTimerProgress, forKey: Self.showProgressKey) }
    }
    @Published var useGroupTimerColors: Bool {
        didSet { userDefaults.set(useGroupTimerColors, forKey: Self.groupTimerColorsKey) }
    }
    /// Colored group labels only: a smaller progress ring, and smaller seconds once hours are shown.
    @Published var useCompactColoredLabels: Bool {
        didSet { userDefaults.set(useCompactColoredLabels, forKey: Self.compactColoredLabelsKey) }
    }
    /// Group mode only: show just the running (or most recently active) timer in the menu bar.
    @Published var showOnlyActiveGroupTimer: Bool {
        didSet { userDefaults.set(showOnlyActiveGroupTimer, forKey: Self.showOnlyActiveGroupTimerKey) }
    }
    /// Tint each group timer's start/pause button with the timer's color.
    @Published var useTimerColorForButtons: Bool {
        didSet { userDefaults.set(useTimerColorForButtons, forKey: Self.timerColorButtonsKey) }
    }
    /// Countdown timers only: show the elapsed time in a smaller font below the remaining time.
    @Published var showElapsedTimeForCountdowns: Bool {
        didSet { userDefaults.set(showElapsedTimeForCountdowns, forKey: Self.showElapsedTimeKey) }
    }
    @Published var showTimerFinishNotification: Bool {
        didSet { userDefaults.set(showTimerFinishNotification, forKey: Self.timerFinishNotificationKey) }
    }
    /// Close the main panel with a two-finger swipe to the right, like a notification.
    @Published var swipeToDismissPanel: Bool {
        didSet { userDefaults.set(swipeToDismissPanel, forKey: Self.swipeToDismissKey) }
    }

    private static let nameDisplayKey = "groupTimerNameDisplay"
    private static let legacyAbbreviateNamesKey = "abbreviateGroupTimerNames"
    private static let showProgressKey = "showGroupTimerProgress"
    private static let groupTimerColorsKey = "useGroupTimerColors"
    private static let compactColoredLabelsKey = "useCompactColoredLabels"
    private static let showOnlyActiveGroupTimerKey = "showOnlyActiveGroupTimer"
    private static let timerColorButtonsKey = "useTimerColorForButtons"
    private static let showElapsedTimeKey = "showElapsedTimeForCountdowns"
    static let timerFinishNotificationKey = "showTimerFinishNotification"
    static let swipeToDismissKey = "swipeToDismissPanel"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let rawValue = userDefaults.string(forKey: Self.nameDisplayKey),
           let display = GroupTimerNameDisplay(rawValue: rawValue) {
            groupTimerNameDisplay = display
        } else if userDefaults.object(forKey: Self.legacyAbbreviateNamesKey) as? Bool == true {
            groupTimerNameDisplay = .firstCharacter
        } else {
            groupTimerNameDisplay = .wholeLabel
        }
        showGroupTimerProgress = userDefaults.object(forKey: Self.showProgressKey) as? Bool ?? true
        useGroupTimerColors = userDefaults.object(forKey: Self.groupTimerColorsKey) as? Bool ?? false
        useCompactColoredLabels = userDefaults.object(forKey: Self.compactColoredLabelsKey) as? Bool ?? false
        showOnlyActiveGroupTimer = userDefaults.object(forKey: Self.showOnlyActiveGroupTimerKey) as? Bool ?? false
        useTimerColorForButtons = userDefaults.object(forKey: Self.timerColorButtonsKey) as? Bool ?? true
        showElapsedTimeForCountdowns = userDefaults.object(forKey: Self.showElapsedTimeKey) as? Bool ?? false
        showTimerFinishNotification = userDefaults.object(forKey: Self.timerFinishNotificationKey) as? Bool ?? true
        swipeToDismissPanel = Self.swipeToDismissEnabled(in: userDefaults)
    }

    static func timerFinishNotificationsEnabled(in userDefaults: UserDefaults) -> Bool {
        userDefaults.object(forKey: timerFinishNotificationKey) as? Bool ?? true
    }

    /// Read directly by `MainPanel`, which has no access to the `AppSettings` environment object.
    static func swipeToDismissEnabled(in userDefaults: UserDefaults) -> Bool {
        userDefaults.object(forKey: swipeToDismissKey) as? Bool ?? true
    }
}

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

/// How the timers other than the active one are drawn in the menu bar in compact mode.
enum CompactInactiveTimerDisplay: String, CaseIterable, Identifiable {
    case none
    /// Left out like `.none`, but each one leaves a small dot behind.
    case dots
    case name
    /// A progress ring with the first character of the timer's name inside it.
    case initialInCircle
    case nameAndProgress
    case nameAndTime

    var id: Self { self }

    var title: String {
        switch self {
        case .none: return "Hidden"
        case .dots: return "Dots"
        case .name: return "Name"
        case .initialInCircle: return "Letter in circle"
        case .nameAndProgress: return "Name and circle"
        case .nameAndTime: return "Name and time"
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
    /// Group labels: a smaller progress ring, and smaller seconds once hours are shown.
    @Published var useCompactColoredLabels: Bool {
        didSet { userDefaults.set(useCompactColoredLabels, forKey: Self.compactColoredLabelsKey) }
    }
    /// Group mode only: show just the running (or most recently active) timer in the menu bar.
    @Published var showOnlyActiveGroupTimer: Bool {
        didSet { userDefaults.set(showOnlyActiveGroupTimer, forKey: Self.showOnlyActiveGroupTimerKey) }
    }
    /// Compact mode only: what is shown of the group's other timers. Names, circles (with or
    /// without a letter) and times can be option- or right-clicked to switch to that timer; dots
    /// are too small for that.
    @Published var compactInactiveTimerDisplay: CompactInactiveTimerDisplay {
        didSet { userDefaults.set(compactInactiveTimerDisplay.rawValue, forKey: Self.compactInactiveTimerDisplayKey) }
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

    /// Keep the main panel above other apps' windows.
    @Published var keepPanelOnTop: Bool {
        didSet { userDefaults.set(keepPanelOnTop, forKey: Self.keepPanelOnTopKey) }
    }

    private static let nameDisplayKey = "groupTimerNameDisplay"
    private static let legacyAbbreviateNamesKey = "abbreviateGroupTimerNames"
    private static let showProgressKey = "showGroupTimerProgress"
    private static let groupTimerColorsKey = "useGroupTimerColors"
    private static let compactColoredLabelsKey = "useCompactColoredLabels"
    private static let showOnlyActiveGroupTimerKey = "showOnlyActiveGroupTimer"
    private static let compactInactiveTimerDisplayKey = "compactInactiveTimerDisplay"
    private static let timerColorButtonsKey = "useTimerColorForButtons"
    private static let showElapsedTimeKey = "showElapsedTimeForCountdowns"
    static let timerFinishNotificationKey = "showTimerFinishNotification"
    static let swipeToDismissKey = "swipeToDismissPanel"
    static let keepPanelOnTopKey = "keepPanelOnTop"
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
        func bool(_ key: String, default defaultValue: Bool) -> Bool {
            Self.bool(key, default: defaultValue, in: userDefaults)
        }
        showGroupTimerProgress = bool(Self.showProgressKey, default: true)
        useGroupTimerColors = bool(Self.groupTimerColorsKey, default: false)
        useCompactColoredLabels = bool(Self.compactColoredLabelsKey, default: false)
        showOnlyActiveGroupTimer = bool(Self.showOnlyActiveGroupTimerKey, default: false)
        compactInactiveTimerDisplay = userDefaults.string(forKey: Self.compactInactiveTimerDisplayKey)
            .flatMap(CompactInactiveTimerDisplay.init(rawValue:)) ?? .none
        useTimerColorForButtons = bool(Self.timerColorButtonsKey, default: true)
        showElapsedTimeForCountdowns = bool(Self.showElapsedTimeKey, default: false)
        showTimerFinishNotification = Self.timerFinishNotificationsEnabled(in: userDefaults)
        swipeToDismissPanel = Self.swipeToDismissEnabled(in: userDefaults)
        keepPanelOnTop = Self.keepPanelOnTopEnabled(in: userDefaults)
    }

    /// Read directly by `TimerModel`, which only has the `UserDefaults` it was created with.
    static func timerFinishNotificationsEnabled(in userDefaults: UserDefaults) -> Bool {
        bool(timerFinishNotificationKey, default: true, in: userDefaults)
    }

    /// Read directly by `MainPanel`, which has no access to the `AppSettings` environment object.
    static func swipeToDismissEnabled(in userDefaults: UserDefaults) -> Bool {
        bool(swipeToDismissKey, default: true, in: userDefaults)
    }

    /// Read directly by `MainWindowController`, which has no access to the `AppSettings` environment object.
    static func keepPanelOnTopEnabled(in userDefaults: UserDefaults) -> Bool {
        bool(keepPanelOnTopKey, default: true, in: userDefaults)
    }

    /// A stored flag, or `defaultValue` while the user hasn't set it (`bool(forKey:)` can't tell an
    /// unset flag from `false`).
    private static func bool(_ key: String, default defaultValue: Bool, in userDefaults: UserDefaults) -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? defaultValue
    }
}

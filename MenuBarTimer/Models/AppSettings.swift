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
        case .wholeLabel: return "Whole label"
        case .firstCharacter: return "First character"
        case .none: return "None"
        }
    }
}

/// User preferences for the compact group representation in the menu bar.
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

    private static let nameDisplayKey = "groupTimerNameDisplay"
    private static let legacyAbbreviateNamesKey = "abbreviateGroupTimerNames"
    private static let showProgressKey = "showGroupTimerProgress"
    private static let groupTimerColorsKey = "useGroupTimerColors"
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
    }
}

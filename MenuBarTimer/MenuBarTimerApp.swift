//
//  MenuBarTimerApp.swift
//  MenuBarTimer
//
//  Created by Leonhard Massloch on 2026/07/14.
//

import SwiftUI

@main
struct MenuBarTimerApp: App {
    @StateObject private var timerModel = TimerModel()
    @StateObject private var presetsStore = PresetsStore()

    var body: some Scene {
        MenuBarExtra {
            TimerPopoverView()
                .environmentObject(timerModel)
                .environmentObject(presetsStore)
        } label: {
            MenuBarLabelView(timerModel: timerModel, presetsStore: presetsStore)
        }
        .menuBarExtraStyle(.window)
    }
}

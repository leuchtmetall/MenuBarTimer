//
//  MenuBarTimerApp.swift
//  MenuBarTimer
//
//  Created by Leonhard Massloch on 2026/07/14.
//

import MenuBarExtraAccess
import SwiftUI

@main
struct MenuBarTimerApp: App {
    @StateObject private var timerModel = TimerModel()
    @StateObject private var groupsStore = TimerGroupsStore()
    @StateObject private var presetsStore = PresetsStore()
    @StateObject private var groupCoordinator = TimerGroupCoordinator()
    @StateObject private var settings = AppSettings()
    @State private var isMenuPresented = false

    var body: some Scene {
        MenuBarExtra {
            TimerPopoverView()
                .environmentObject(timerModel)
                .environmentObject(presetsStore)
                .environmentObject(groupsStore)
                .environmentObject(groupCoordinator)
                .environmentObject(settings)
        } label: {
            MenuBarLabelView(timerModel: timerModel, presetsStore: presetsStore, groupsStore: groupsStore, groupCoordinator: groupCoordinator, settings: settings)
                .id(groupsStore.selectedGroupID?.uuidString ?? presetsStore.selectedPresetID?.uuidString ?? "timer")
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            guard let button = statusItem.button else { return }
            if let handler = button.subviews.compactMap({ $0 as? RightClickHandlerView }).first {
                handler.frame = button.bounds
                handler.autoresizingMask = [.width, .height]
                handler.onRightMouseDown = {
                    if groupCoordinator.model == nil { timerModel.primaryButtonTapped() }
                }
            } else {
                let handler = RightClickHandlerView(frame: button.bounds)
                handler.autoresizingMask = [.width, .height]
                handler.onRightMouseDown = {
                    if groupCoordinator.model == nil { timerModel.primaryButtonTapped() }
                }
                button.addSubview(handler)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

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
    /// Written by `MenuBarLabelView` while it composes the label, read by the right-click handler.
    private let labelLayout = MenuBarLabelLayout()

    init() {
        TimerCompletionNotifier.configure()
    }

    var body: some Scene {

        let popoverView = TimerPopoverView()
            .environmentObject(timerModel)
            .environmentObject(presetsStore)
            .environmentObject(groupsStore)
            .environmentObject(groupCoordinator)
            .environmentObject(settings)
        MenuBarExtra {
            popoverView
        } label: {
            MenuBarLabelView(timerModel: timerModel, presetsStore: presetsStore, groupsStore: groupsStore, groupCoordinator: groupCoordinator, settings: settings, layout: labelLayout)
                .id(groupsStore.selectedGroupID?.uuidString ?? presetsStore.selectedPresetID?.uuidString ?? "timer")
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            guard let button = statusItem.button else { return }
            let onRightMouseDown: (CGPoint) -> Void = { point in
                guard let groupModel = groupCoordinator.model else {
                    timerModel.primaryButtonTapped()
                    return
                }
                // In group mode the label is one flat Text/Image, so the click position decides
                // which timer was hit. `start` also pauses the group's other timers.
                guard let timerID = labelLayout.timerID(atX: point.x, boundsWidth: button.bounds.width),
                      let definition = groupModel.group.timers.first(where: { $0.id == timerID }) else { return }
                groupModel.start(definition)
            }
            if let handler = button.subviews.compactMap({ $0 as? RightClickHandlerView }).first {
                handler.frame = button.bounds
                handler.autoresizingMask = [.width, .height]
                handler.onRightMouseDown = onRightMouseDown
            } else {
                let handler = RightClickHandlerView(frame: button.bounds)
                handler.autoresizingMask = [.width, .height]
                handler.onRightMouseDown = onRightMouseDown
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

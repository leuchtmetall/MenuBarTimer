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
            let handler = button.subviews.compactMap({ $0 as? RightClickHandlerView }).first
                ?? RightClickHandlerView(frame: button.bounds)
            if handler.superview == nil { button.addSubview(handler) }
            handler.frame = button.bounds
            handler.autoresizingMask = [.width, .height]
            handler.onRightMouseDown = { [weak handler] point in
                guard let handler else { return }
                let contentFrame = handler.labelContentFrame
                guard let groupModel = groupCoordinator.model else {
                    timerModel.primaryButtonTapped()
                    let frame = contentFrame ?? handler.bounds
                    handler.flash(minX: frame.minX, width: frame.width)
                    return
                }
                // In group mode the label is one flat Text/Image, so the click position decides
                // which timer was hit. `start` also pauses the group's other timers.
                guard let hit = labelLayout.hit(atX: point.x, boundsWidth: handler.bounds.width, contentFrame: contentFrame),
                      let definition = groupModel.group.timers.first(where: { $0.id == hit.timerID }) else { return }
                groupModel.start(definition)
                let color = settings.useGroupTimerColors && definition.colorName != nil ? NSColor(definition.color) : nil
                handler.flash(minX: hit.minX, width: hit.width, color: color)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

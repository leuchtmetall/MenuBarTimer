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
    @StateObject private var menuBarAppearance = MenuBarAppearance()
    @State private var isMenuPresented = false
    /// Written by `MenuBarLabelView` while it composes the label, read by the right-click handler.
    private let labelLayout = MenuBarLabelLayout()
    private let mainWindow = MainWindowController()

    init() {
        TimerCompletionNotifier.configure()
    }

    var body: some Scene {
        // The content is never shown: `mainWindow` takes over left-clicks and shows its own panel.
        MenuBarExtra {
            EmptyView()
        } label: {
            MenuBarLabelView(timerModel: timerModel, presetsStore: presetsStore, groupsStore: groupsStore, groupCoordinator: groupCoordinator, settings: settings, menuBarAppearance: menuBarAppearance, layout: labelLayout)
                .id(groupsStore.selectedGroupID?.uuidString ?? presetsStore.selectedPresetID?.uuidString ?? "timer")
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            configure(statusItem)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }

    /// Routes the status item's clicks to the app: left-clicks toggle the main panel, right-clicks
    /// start or pause a timer. `MenuBarExtraAccess` calls this on every status item update, so
    /// everything here is safe to repeat.
    private func configure(_ statusItem: NSStatusItem) {
        guard let button = statusItem.button else { return }
        mainWindow.attach(to: statusItem) {
            TimerPopoverView()
                .environmentObject(timerModel)
                .environmentObject(presetsStore)
                .environmentObject(groupsStore)
                .environmentObject(groupCoordinator)
                .environmentObject(settings)
        }

        let handler = button.subviews.compactMap({ $0 as? RightClickHandlerView }).first
            ?? RightClickHandlerView(frame: button.bounds)
        if handler.superview == nil { button.addSubview(handler) }
        handler.frame = button.bounds
        handler.autoresizingMask = [.width, .height]

        handler.onAppearanceChange = { menuBarAppearance.update(from: $0) }
        // Deferred: this can run while SwiftUI is updating the label.
        DispatchQueue.main.async { [weak handler] in
            guard let handler else { return }
            menuBarAppearance.update(from: handler.effectiveAppearance)
        }

        handler.onLeftMouseDown = { mainWindow.toggle() }
        handler.onRightMouseDown = { [weak handler] point in
            guard let handler else { return }
            handleRightClick(at: point, in: handler)
        }
    }

    /// Starts or pauses the timer that was right-clicked and flashes its part of the label.
    private func handleRightClick(at point: CGPoint, in handler: RightClickHandlerView) {
        let contentFrame = handler.labelContentFrame
        guard let groupModel = groupCoordinator.model else {
            timerModel.primaryButtonTapped()
            let frame = contentFrame ?? handler.bounds
            handler.flash(minX: frame.minX, width: frame.width)
            return
        }
        // In group mode the label is one flat Text/Image, so the click position decides which timer
        // was hit. `start` also pauses the group's other timers.
        guard let hit = labelLayout.hit(atX: point.x, boundsWidth: handler.bounds.width, contentFrame: contentFrame),
              let definition = groupModel.group.timers.first(where: { $0.id == hit.timerID }) else { return }
        groupModel.start(definition)
        let color = settings.useGroupTimerColors && definition.colorName != nil ? NSColor(definition.color) : nil
        handler.flash(minX: hit.minX, width: hit.width, color: color)
    }
}

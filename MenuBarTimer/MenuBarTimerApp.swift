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
    @StateObject private var presetsStore = PresetsStore()
    @State private var isMenuPresented = false

    var body: some Scene {
        MenuBarExtra {
            TimerPopoverView()
                .environmentObject(timerModel)
                .environmentObject(presetsStore)
        } label: {
            MenuBarLabelView(timerModel: timerModel, presetsStore: presetsStore)
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            guard let button = statusItem.button else { return }
            if let handler = button.subviews.compactMap({ $0 as? RightClickHandlerView }).first {
                handler.frame = button.bounds
                handler.onRightMouseDown = { timerModel.primaryButtonTapped() }
            } else {
                let handler = RightClickHandlerView(frame: button.bounds)
                handler.autoresizingMask = [.width, .height]
                handler.onRightMouseDown = { timerModel.primaryButtonTapped() }
                button.addSubview(handler)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

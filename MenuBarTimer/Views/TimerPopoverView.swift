//
//  TimerPopoverView.swift
//  MenuBarTimer
//

import SwiftUI

/// The overlay window shown when the menu bar item is clicked.
struct TimerPopoverView: View {
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var presetsStore: PresetsStore
    @EnvironmentObject var groupsStore: TimerGroupsStore
    @EnvironmentObject var groupCoordinator: TimerGroupCoordinator

    var body: some View {
        HStack(spacing: 0) {
            TimerControlView(timerModel: timerModel)
            Divider()
            PresetsListView(timerModel: timerModel, presetsStore: presetsStore, groupsStore: groupsStore, groupCoordinator: groupCoordinator)
        }
        .fixedSize()
    }
}

#Preview {
    TimerPopoverView()
        .environmentObject(TimerModel())
        .environmentObject(PresetsStore())
        .environmentObject(TimerGroupsStore())
        .environmentObject(TimerGroupCoordinator())
}

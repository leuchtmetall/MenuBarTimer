//
//  TimerControlView.swift
//  MenuBarTimer
//

import SwiftUI

/// The timer display and its controls. Groups render one complete control panel per timer.
struct TimerControlView: View {
    @ObservedObject var timerModel: TimerModel
    @EnvironmentObject private var groupCoordinator: TimerGroupCoordinator

    var body: some View {
        if let groupModel = groupCoordinator.model {
            TimerGroupControlView(groupModel: groupModel)
        } else {
            SingleTimerControlView(timerModel: timerModel)
        }
    }
}

private struct SingleTimerControlView: View {
    @ObservedObject var timerModel: TimerModel

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                if timerModel.preset.type == .countdown {
                    DonutProgressView(
                        progress: timerModel.progress,
                        lineWidth: 14,
                        onProgressChange: { timerModel.setProgress($0) }
                    )
                    .frame(width: 180, height: 180)
                }

                VStack(spacing: 4) {
                    Text(timerModel.timeString)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if timerModel.canUndoAdjustment {
                        Button(action: { timerModel.undoAdjustment() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .accessibilityLabel("Undo timer adjustment")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 14) {
                Button(action: { timerModel.primaryButtonTapped() }) {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                        .frame(minWidth: 72)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!timerModel.hasLoadedTimer)

                Button(action: { timerModel.stop() }) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(minWidth: 72)
                }
                .buttonStyle(.bordered)
                .disabled(!timerModel.hasLoadedTimer)
            }
        }
        .padding(28)
        .frame(width: 260)
    }    
  
    private var statusText: String {
        switch timerModel.state {
        case .idle: return "Ready"
        case .running: return "Running"
        case .paused: return "Paused"
        case .finished: return "Done!"
        }
    }

    private var primaryButtonTitle: String { timerModel.state == .running ? "Pause" : "Start" }
    private var primaryButtonIcon: String { timerModel.state == .running ? "pause.fill" : "play.fill" }
}

private struct TimerGroupControlView: View {
    @ObservedObject var groupModel: TimerGroupModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(zip(groupModel.group.timers.indices, groupModel.group.timers)), id: \.1.id) { index, definition in
                GroupTimerControlPanel(
                    definition: definition,
                    timer: groupModel.timerModels[index],
                    onStart: { groupModel.start(definition) }
                )
            }
        }
        .padding(20)
        .fixedSize()
    }
}

private struct GroupTimerControlPanel: View {
    let definition: TimerPreset
    @ObservedObject var timer: TimerModel
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(definition.name ?? "")
                .font(.headline)
                .foregroundStyle(definition.color)
                .lineLimit(1)

            ZStack {
                if timer.preset.type == .countdown {
                    DonutProgressView(
                        progress: timer.progress,
                        lineWidth: 12,
                        onProgressChange: { timer.setProgress($0) }
                    )
                    .frame(width: 150, height: 150)
                }

                VStack(spacing: 3) {
                    Text(displayTime)
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if timer.canUndoAdjustment {
                        Button(action: { timer.undoAdjustment() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .accessibilityLabel("Undo \(definition.name ?? "timer") adjustment")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 6) {
                Button(action: onStart) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .accessibilityLabel(timer.state == .running ? "Pause \(definition.name)" : "Start \(definition.name)")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!timer.hasLoadedTimer)

                Button(action: { timer.stop() }) {
                    Image(systemName: "stop.fill")
                        .accessibilityLabel("Stop \(definition.name)")
                }
                .buttonStyle(.bordered)
                .disabled(!timer.hasLoadedTimer)
            }
        }
        .frame(width: 190)
    }

    private var displayTime: String {
        timer.preset.type == .countUp ? timer.remaining.formattedElapsedClock : timer.remaining.formattedClock
    }

    private var statusText: String {
        switch timer.state {
        case .idle: return "Ready"
        case .running: return "Running"
        case .paused: return "Paused"
        case .finished: return "Done!"
        }
    }
}

#Preview {
    TimerControlView(timerModel: TimerModel())
        .environmentObject(TimerGroupCoordinator())
}

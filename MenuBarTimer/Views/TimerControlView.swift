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
            TimerDial(timer: timerModel, style: .single, undoLabel: "Undo timer adjustment")

            HStack(spacing: 14) {
                Button(action: { timerModel.primaryButtonTapped() }) {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                        .frame(minWidth: 72)
                }
                .buttonStyle(.glassProminent)
                .disabled(!timerModel.hasLoadedTimer)

                Button(action: { timerModel.stop() }) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(minWidth: 72)
                }
                .buttonStyle(.glass)
                .disabled(!timerModel.hasLoadedTimer)
            }
        }
        .padding(28)
        .frame(width: 260)
    }

    private var primaryButtonTitle: String { timerModel.state == .running ? "Pause" : "Start" }
    private var primaryButtonIcon: String { timerModel.state == .running ? "pause.fill" : "play.fill" }
}

private struct TimerGroupControlView: View {
    @ObservedObject var groupModel: TimerGroupModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Matches the presets list header (same top padding and control size) so these buttons
            // line up with its Edit button.
            headerRow

            Spacer(minLength: 12)

            HStack(alignment: .top, spacing: 12) {
                ForEach(groupModel.timerModels, id: \.preset.id) { timer in
                    GroupTimerControlPanel(timer: timer, onStart: { groupModel.start(timer.preset) })
                }
            }

            Spacer(minLength: 12)

            // Invisible counterweight with the header's exact height, so the timers are
            // centered on the full window height rather than the space below the header.
            headerRow
                .hidden()
                .accessibilityHidden(true)
        }
        // Fill the popover's height (it is top-aligned in group mode) so the spacers can
        // center the timers vertically.
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $settings.showOnlyActiveGroupTimer) {
                Label("Compact", systemImage: "rectangle.compress.vertical")
            }
            .toggleStyle(.button)
            .buttonStyle(.glass)
            .help("Show only the active timer in the menu bar")

            // Space is always reserved so the popover doesn't jump.
            resetButton
                .opacity(groupModel.isInInitialState ? 0 : 1)
                .disabled(groupModel.isInInitialState)
                .accessibilityHidden(groupModel.isInInitialState)
        }
    }

    private var resetButton: some View {
        Button("Reset All Timers") { groupModel.resetAll() }
            .buttonStyle(.glass)
    }
}

private struct GroupTimerControlPanel: View {
    @ObservedObject var timer: TimerModel
    let onStart: () -> Void
    @EnvironmentObject private var settings: AppSettings

    private var name: String { timer.preset.name }

    var body: some View {
        VStack(spacing: 10) {
            Text(name)
                .font(.headline)
                .foregroundStyle(timer.preset.color)
                .lineLimit(1)

            TimerDial(timer: timer, style: .group, undoLabel: "Undo \(name) adjustment")

            HStack(spacing: 6) {
                Button(action: onStart) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .accessibilityLabel(timer.state == .running ? "Pause \(name)" : "Start \(name)")
                }
                .buttonStyle(.glassProminent)
                .tint(settings.useTimerColorForButtons ? timer.preset.color : nil)
                .disabled(!timer.hasLoadedTimer)

                Button(action: { timer.stop() }) {
                    Image(systemName: "stop.fill")
                        .accessibilityLabel("Stop \(name)")
                }
                .buttonStyle(.glass)
                .disabled(!timer.hasLoadedTimer)
            }
        }
        .frame(width: 190)
    }
}

/// A timer's progress ring (countdowns only) around its time, state and undo button. Shared by the
/// single timer and by every timer of a group, which differ only in size.
private struct TimerDial: View {
    struct Style {
        let diameter: CGFloat
        let lineWidth: CGFloat
        let timeFontSize: CGFloat
        let elapsedFontSize: CGFloat
        let spacing: CGFloat

        static let single = Style(diameter: 180, lineWidth: 14, timeFontSize: 32, elapsedFontSize: 15, spacing: 4)
        static let group = Style(diameter: 150, lineWidth: 12, timeFontSize: 25, elapsedFontSize: 13, spacing: 3)
    }

    @ObservedObject var timer: TimerModel
    let style: Style
    /// Accessibility label of the undo button, which names the timer in a group.
    let undoLabel: String
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            if timer.preset.type == .countdown {
                DonutProgressView(
                    progress: timer.progress,
                    lineWidth: style.lineWidth,
                    onProgressChange: { timer.setProgress($0) }
                )
                .frame(width: style.diameter, height: style.diameter)
            }

            VStack(spacing: style.spacing) {
                Text(timer.timeString)
                    .font(.system(size: style.timeFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if settings.showElapsedTimeForCountdowns, let elapsed = timer.elapsedTimeString {
                    ElapsedTimeText(elapsed: elapsed, size: style.elapsedFontSize)
                }
                Text(timer.state.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if timer.canUndoAdjustment {
                    Button(action: { timer.undoAdjustment() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .accessibilityLabel(undoLabel)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }
}

/// The elapsed time of a countdown, shown smaller below its remaining time.
private struct ElapsedTimeText: View {
    let elapsed: String
    let size: CGFloat

    var body: some View {
        Text(elapsed)
            .font(.system(size: size, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .accessibilityLabel("Elapsed \(elapsed)")
    }
}

#Preview {
    TimerControlView(timerModel: TimerModel())
        .environmentObject(TimerGroupCoordinator())
        .environmentObject(AppSettings())
}

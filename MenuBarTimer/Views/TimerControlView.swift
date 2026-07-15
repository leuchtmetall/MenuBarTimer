//
//  TimerControlView.swift
//  MenuBarTimer
//

import SwiftUI

/// The left-hand side of the overlay: the timer display and its controls.
struct TimerControlView: View {
    @ObservedObject var timerModel: TimerModel

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                if timerModel.timerType == .countdown {
                    DonutProgressView(
                        progress: timerModel.progress,
                        lineWidth: 14,
                        onProgressChange: { timerModel.setProgress($0) }
                    )
                    .frame(width: 180, height: 180)
                }

                VStack(spacing: 4) {
                    Text(displayTime)
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
                        .help("Undo timer adjustment")
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: timerModel.canUndoAdjustment)

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

    private var displayTime: String {
        timerModel.remaining.formattedClock
    }



    private var statusText: String {
        switch timerModel.state {
        case .idle: return "Ready"
        case .running: return "Running"
        case .paused: return "Paused"
        case .finished: return "Done!"
        }
    }

    private var primaryButtonTitle: String {
        timerModel.state == .running ? "Pause" : "Start"
    }

    private var primaryButtonIcon: String {
        timerModel.state == .running ? "pause.fill" : "play.fill"
    }
}

#Preview {
    TimerControlView(timerModel: TimerModel())
}

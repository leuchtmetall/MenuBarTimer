//
//  TimerControlView.swift
//  MenuBarTimer
//

import SwiftUI

/// The left-hand side of the overlay: the big countdown ring and its controls.
struct TimerControlView: View {
    @ObservedObject var timerModel: TimerModel

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                DonutProgressView(progress: timerModel.progress, lineWidth: 14)
                    .frame(width: 180, height: 180)

                VStack(spacing: 4) {
                    Text(displayTime)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                Button(action: { timerModel.primaryButtonTapped() }) {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                        .frame(minWidth: 72)
                }
                .buttonStyle(.borderedProminent)
                .disabled(timerModel.totalDuration == 0)

                Button(action: { timerModel.stop() }) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(minWidth: 72)
                }
                .buttonStyle(.bordered)
                .disabled(timerModel.totalDuration == 0)
            }
        }
        .padding(28)
        .frame(width: 260)
    }

    private var displayTime: String {
        timerModel.totalDuration > 0 ? timerModel.remaining.formattedClock : TimeInterval(0).formattedClock
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

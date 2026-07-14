//
//  DonutProgressView.swift
//  MenuBarTimer
//

import SwiftUI

/// A donut-shaped progress ring that fills clockwise from the top.
struct DonutProgressView: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var progressColor: Color = .blue
    var trackColor: Color = Color.secondary.opacity(0.2)

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
//                .animation(.bouncy(duration: 0.05), value: progress)
        }
    }
}

#Preview {
    DonutProgressView(progress: 0.65)
        .frame(width: 120, height: 120)
        .padding()
}

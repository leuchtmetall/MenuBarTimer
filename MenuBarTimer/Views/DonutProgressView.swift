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
    var onProgressChange: ((Double) -> Void)?

    /// Extra hit-test tolerance on each side of the ring, so thin rings are still easy to grab.
    private let hitSlop: CGFloat = 4

    var body: some View {
        // The stroke is centered on the circle's path, so half of it lies outside the view's frame.
        // Expand the hit area outward so the whole visible ring (plus slop) is grabbable, and
        // only the ring — not its interior — starts a drag.
        let outset = lineWidth / 2 + hitSlop
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(outset)
            .contentShape(Circle().inset(by: outset).stroke(lineWidth: lineWidth + 2 * hitSlop))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { value in
                        onProgressChange?(progress(at: value.location, in: geometry.size))
                    }
            )
            .padding(-outset)
        }
        .coordinateSpace(.named(Self.coordinateSpace))
    }

    private static let coordinateSpace = "DonutProgressView"

    private func progress(at location: CGPoint, in size: CGSize) -> Double {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let x = location.x - center.x
        let y = location.y - center.y
        var angle = atan2(x, -y)
        if angle < 0 { angle += 2 * .pi }
        return angle / (2 * .pi)
    }
}

#Preview {
    DonutProgressView(progress: 0.65)
        .frame(width: 120, height: 120)
        .padding()
}

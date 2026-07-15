//
//  PieProgressView.swift
//  MenuBarTimer
//

import SwiftUI

/// A circular progress indicator that fills with a solid, pie-shaped wedge, clockwise from the top.
///
/// This is drawn in plain black and is meant to be rasterized into a *template* `NSImage`
/// for use in the menu bar: macOS discards the actual color and re-tints the opaque pixels
/// to match the current menu bar foreground color, so it stays visible in both light and dark mode.
struct PieProgressView: View {
    var progress: Double
    var trackOpacity: Double = 0.2

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .stroke(.foreground, style: .init(lineWidth: 1))

                Path { path in
                    let center = CGPoint(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2 + 0.5 // offset by 0.5 so the center point is filled. Otherwise, thin slices would look too short.
                    )

                    path.move(to: center)
                    path.addLine(
                        to: CGPoint(
                            x: center.x,
                            y: 0
                        ))
                }
                .stroke(.black, lineWidth: 0.5)
                PieSliceShape(progress: progress)
                    .fill(.black)
                    .rotationEffect(.degrees(-90)) // rotate, so the slice starts at the 12 o'clock position.
            }

        }
    }
}

private struct PieSliceShape: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * clamped),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    PieProgressView(progress: 0.65)
        .frame(width: 60, height: 60)
        .padding()
}

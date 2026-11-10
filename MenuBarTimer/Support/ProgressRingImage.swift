//
//  ProgressRingImage.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

/// The pie-style progress ring shown in the menu bar, rasterized from `PieProgressView`.
///
/// The menu bar label is rebuilt every second, and a ring is drawn for every countdown timer in it,
/// most of which haven't visibly changed. Rendered rings are therefore cached, with the progress
/// snapped to `steps` positions so that neighbouring values share an image.
enum ProgressRingImage {
    /// How many distinct fill levels a ring has. One step is about a pixel of arc on the largest
    /// menu bar ring at 2x, so snapping to it isn't visible.
    static let steps = 120

    private struct Key: Hashable {
        let step: Int
        let size: CGFloat
        let scale: CGFloat
    }

    /// At most `steps + 1` images per ring size and display scale, so this stays small.
    private static var cache: [Key: NSImage] = [:]

    /// A template image of the ring, `size` points wide and high. The same instance is returned for
    /// every progress that snaps to the same step.
    static func image(progress: Double, size: CGFloat) -> NSImage {
        let key = Key(step: step(for: progress), size: size, scale: NSScreen.highestBackingScaleFactor)
        if let cached = cache[key] { return cached }

        let renderer = ImageRenderer(content:
            PieProgressView(progress: Double(key.step) / Double(steps))
                .padding(1)
                .frame(width: size, height: size)
        )
        renderer.scale = key.scale
        renderer.proposedSize = ProposedViewSize(width: size, height: size)
        // A failed render isn't cached, so the next label update tries again.
        guard let image = renderer.nsImage else { return NSImage(size: NSSize(width: size, height: size)) }
        image.isTemplate = true
        cache[key] = image
        return image
    }

    /// Rounded down, so the ring only looks complete once the timer has actually finished.
    static func step(for progress: Double) -> Int {
        Int((min(max(progress, 0), 1) * Double(steps)).rounded(.down))
    }
}

extension NSScreen {
    /// The scale to rasterize menu bar content at: the sharpest attached display's. The menu bar is
    /// on every display, and `NSScreen.main` is only the one with the key window.
    static var highestBackingScaleFactor: CGFloat {
        screens.map(\.backingScaleFactor).max() ?? 2
    }
}

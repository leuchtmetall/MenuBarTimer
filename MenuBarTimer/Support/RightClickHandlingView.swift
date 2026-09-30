//
//  RightClickHandlingView.swift
//  MenuBarTimer
//

import AppKit

/// A transparent overlay added on top of the menu bar item's button that only reacts
/// to right-clicks.
///
/// `MenuBarExtra` doesn't expose a way to distinguish left- and right-clicks on its
/// label directly, and the label content itself isn't a fully live/interactive view
/// (only `Text`/`Image` are rendered; other content, including `NSViewRepresentable`,
/// is effectively dropped). The `MenuBarExtraAccess` package gives us access to the
/// underlying `NSStatusItem`, so instead we add this view directly as a subview of the
/// real status item button.
///
/// Only `rightMouseDown` is overridden (per the pattern documented in
/// https://github.com/orchetect/MenuBarExtraAccess/discussions/2). Left-clicks are left
/// completely untouched here, so `MenuBarExtra`'s own click handling (opening/closing the
/// popover) keeps working unmodified.
final class RightClickHandlerView: NSView {
    /// Called with the click location in this view's own coordinate space. Because the view is
    /// sized to (and autoresizes with) the status item button's bounds, that is also the button's
    /// coordinate space, which is what `MenuBarLabelLayout` hit-tests against.
    var onRightMouseDown: ((CGPoint) -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        if let onRightMouseDown {
            onRightMouseDown(clickLocation(for: event))
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
    }

    /// Where the click happened, in this view's coordinate space.
    ///
    /// `event.locationInWindow` can't be used: for status item clicks macOS reports the center of
    /// the button there, wherever the cursor actually was. The cursor's screen position
    /// (`NSEvent.mouseLocation`) is accurate, so the click is located from that instead.
    private func clickLocation(for event: NSEvent) -> CGPoint {
        guard let window else { return convert(event.locationInWindow, from: nil) }
        let mouse = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        let windowX = Self.windowX(
            ofScreenX: mouse.x,
            windowFrame: window.frame,
            windowScreenFrame: window.screen?.frame,
            mouseScreenFrame: mouseScreen?.frame
        )
        return convert(CGPoint(x: windowX, y: event.locationInWindow.y), from: nil)
    }

    /// Converts a screen x coordinate into the status item window's coordinate space.
    ///
    /// With several displays every one shows the status item, but there is only one window and it
    /// may still sit on another display when the click arrives. Status items keep the same distance
    /// from the right edge of each display's menu bar, so the window's position is mirrored onto
    /// the display the cursor is on before converting.
    static func windowX(
        ofScreenX x: CGFloat,
        windowFrame: CGRect,
        windowScreenFrame: CGRect?,
        mouseScreenFrame: CGRect?
    ) -> CGFloat {
        guard let windowScreenFrame, let mouseScreenFrame, windowScreenFrame != mouseScreenFrame else {
            return x - windowFrame.minX
        }
        let distanceFromRightEdge = windowScreenFrame.maxX - windowFrame.minX
        return x - (mouseScreenFrame.maxX - distanceFromRightEdge)
    }

    /// Where the status item button actually draws its label, in this view's coordinate space.
    ///
    /// `MenuBarExtra` turns a `Text` label into the button's `attributedTitle` (drawn in the menu bar
    /// font, whatever `.font` the SwiftUI `Text` had) and an `Image` label into the button's `image`,
    /// so the button's cell knows the real on-screen geometry of the label.
    var labelContentFrame: CGRect? {
        guard let button = superview as? NSButton, let cell = button.cell else { return nil }
        var frame: CGRect?
        if button.image != nil, button.imagePosition != .noImage {
            frame = cell.imageRect(forBounds: button.bounds)
        }
        if button.attributedTitle.length > 0 {
            let titleRect = cell.titleRect(forBounds: button.bounds)
            let textWidth = min(button.attributedTitle.size().width, titleRect.width)
            let textFrame = CGRect(x: titleRect.midX - textWidth / 2, y: titleRect.minY,
                                   width: textWidth, height: titleRect.height)
            frame = frame.map { $0.union(textFrame) } ?? textFrame
        }
        guard let frame, frame.width > 0 else { return nil }
        return convert(frame, from: button)
    }

    /// Briefly highlights the horizontal span `minX ..< minX + width` to acknowledge a right-click.
    ///
    /// Drawn here rather than in the label: this view is a real AppKit view on top of the status
    /// item button, whereas the SwiftUI label is flattened into a plain title or image.
    func flash(minX: CGFloat, width: CGFloat, color: NSColor? = nil) {
        wantsLayer = true
        guard let layer else { return }

        let highlight = CALayer()
        let rect = CGRect(x: minX, y: bounds.minY, width: width, height: bounds.height)
            .insetBy(dx: -3, dy: 1)
            .intersection(bounds)
        highlight.frame = rect
        highlight.cornerRadius = 4
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let fill = color?.withAlphaComponent(0.35) ?? NSColor.labelColor.withAlphaComponent(0.25)
            highlight.backgroundColor = fill.cgColor
        }
        highlight.opacity = 0
        layer.addSublayer(highlight)

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.1, 0.4, 1]
        fade.duration = 0.45
        CATransaction.begin()
        CATransaction.setCompletionBlock { highlight.removeFromSuperlayer() }
        highlight.add(fade, forKey: "flash")
        CATransaction.commit()
    }
}

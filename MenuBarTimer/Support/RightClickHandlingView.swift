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
            onRightMouseDown(convert(event.locationInWindow, from: nil))
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
    }

}

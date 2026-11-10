//
//  MainPanel.swift
//  MenuBarTimer
//

import AppKit

/// A borderless panel that can still become key, so text fields and key handling in the UI work.
final class MainPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Called when Escape reaches the window.
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    // MARK: Swipe to dismiss

    /// Called after a two-finger swipe to the right has slid the panel away.
    var onSwipeDismiss: (() -> Void)?

    private var swipeTracker = SwipeToDismissTracker()
    /// The panel's origin when the current swipe began; the panel returns here afterwards.
    private var swipeStartOrigin: CGPoint?

    /// Moves the panel along with a two-finger swipe to the right and dismisses it on release, like a
    /// notification. Returns whether the event was consumed. Does nothing when the setting is off.
    private func handleSwipe(_ event: NSEvent) -> Bool {
        guard swipeStartOrigin != nil || AppSettings.swipeToDismissEnabled(in: .standard) else { return false }
        guard let sample = SwipeToDismissTracker.Sample(event) else { return false }
        switch swipeTracker.handle(sample) {
        case .passThrough:
            return false
        case .ignore:
            return true
        case .track(let offset):
            let start = swipeStartOrigin ?? frame.origin
            swipeStartOrigin = start
            setFrameOrigin(CGPoint(x: start.x + offset, y: start.y))
            alphaValue = 1 - min(offset / frame.width, 1) * 0.7
        case .restore:
            guard let start = swipeStartOrigin else { return true }
            swipeStartOrigin = nil
            // A window's animator only animates `setFrame(_:display:)`; `setFrameOrigin` jumps or is
            // dropped, so both animations go through the full frame.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(CGRect(origin: start, size: frame.size), display: true)
                animator().alphaValue = 1
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.swipeStartOrigin == nil else { return }
                    self.setFrameOrigin(start)
                    self.alphaValue = 1
                }
            }
        case .dismiss(let velocity):
            guard let start = swipeStartOrigin else { return true }
            swipeStartOrigin = nil
            let screenMaxX = (screen ?? NSScreen.main)?.frame.maxX ?? frame.maxX
            let targetX = max(screenMaxX, frame.minX + frame.width) + 20
            let distance = targetX - frame.minX
            NSAnimationContext.runAnimationGroup { context in
                // Keep at least the finger's speed, but never drag on.
                context.duration = min(0.25, max(0.1, Double(distance / max(velocity, 1))))
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(CGRect(origin: CGPoint(x: targetX, y: start.y), size: frame.size), display: true)
                animator().alphaValue = 0
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.onSwipeDismiss?()
                    // Reopening shows the panel where it was before the swipe.
                    self.setFrameOrigin(start)
                    self.alphaValue = 1
                }
            }
        }
        return true
    }

    // MARK: Tab order

    // SwiftUI's own key view loop is unusable here: it runs across both columns by vertical position
    // (jumping between the presets and the timer controls), and it dead-ends inside AppKit views such
    // as `DurationPicker`, whose host view links back to the hosting view instead of to the next
    // control. The panel therefore orders all focusable views itself: the timer column, then the
    // presets column; within a column top to bottom, and left to right within a line.
    //
    // SwiftUI controls and text fields handle Tab themselves without asking the window, so Tab is
    // intercepted here before it reaches them. Views that use Tab internally adopt `TabKeyHandling`
    // and get it as usual; they leave through `selectNextKeyView` / `selectPreviousKeyView`.

    override func sendEvent(_ event: NSEvent) {
        if handleSwipe(event) { return }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        if event.type == .keyDown, event.keyCode == KeyCode.tab, modifiers.isEmpty,
           !(firstResponder is TabKeyHandling) {
            moveFocus(from: firstResponder as? NSView, forward: !event.modifierFlags.contains(.shift))
            return
        }
        super.sendEvent(event)
    }

    /// The presets column's current width, which changes in expanded edit mode. Written by
    /// `PresetsListView` whenever its width changes; read only when computing the tab order.
    static var presetsColumnWidth: CGFloat = PresetsListView.width

    override func selectNextKeyView(_ sender: Any?) {
        moveFocus(from: firstResponder as? NSView, forward: true)
    }

    override func selectPreviousKeyView(_ sender: Any?) {
        moveFocus(from: firstResponder as? NSView, forward: false)
    }

    override func selectKeyView(following view: NSView) {
        moveFocus(from: view, forward: true)
    }

    override func selectKeyView(preceding view: NSView) {
        moveFocus(from: view, forward: false)
    }

    private func moveFocus(from current: NSView?, forward: Bool) {
        let views = orderedKeyViews()
        guard !views.isEmpty else { return }
        // The responder may be inside a key view, e.g. a text field's field editor.
        let index = current.flatMap { current in
            views.firstIndex { current === $0 || current.isDescendant(of: $0) }
        }
        let next: Int
        if let index {
            next = (index + (forward ? 1 : -1) + views.count) % views.count
        } else {
            next = forward ? 0 : views.count - 1
        }
        makeFirstResponder(views[next])
    }

    private func orderedKeyViews() -> [NSView] {
        guard let contentView else { return [] }
        var candidates: [(view: NSView, frame: CGRect)] = []
        func collect(_ view: NSView) {
            for subview in view.subviews where !subview.isHidden {
                let frame = subview.convert(subview.bounds, to: nil)
                if subview.canBecomeKeyView, !frame.isEmpty {
                    candidates.append((subview, frame))
                } else if !(subview is NSControl) {
                    // Controls' subviews (a text field's field editor, a stepper's internals) are
                    // never tab stops of their own.
                    collect(subview)
                }
            }
        }
        collect(contentView)

        let presetsColumnMinX = contentView.bounds.maxX - Self.presetsColumnWidth
        let columns = [
            candidates.filter { $0.frame.midX < presetsColumnMinX },
            candidates.filter { $0.frame.midX >= presetsColumnMinX },
        ]
        return columns.flatMap { column in
            // Window coordinates have y pointing up, so top to bottom is descending y.
            var lines: [[(view: NSView, frame: CGRect)]] = []
            for candidate in column.sorted(by: { $0.frame.midY > $1.frame.midY }) {
                // Views whose vertical centre lies within the current line's first view share a line.
                if let first = lines.last?.first, candidate.frame.midY >= first.frame.minY {
                    lines[lines.count - 1].append(candidate)
                } else {
                    lines.append([candidate])
                }
            }
            return lines.flatMap { $0.sorted { $0.frame.minX < $1.frame.minX }.map(\.view) }
        }
    }
}

/// A view that handles the Tab key itself instead of leaving it to `MainPanel`'s tab order.
protocol TabKeyHandling: NSView {}

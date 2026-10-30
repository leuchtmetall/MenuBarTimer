//
//  MainWindowController.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

/// Shows the main UI in a floating panel that a left-click on the menu bar item toggles.
///
/// This replaces `MenuBarExtra`'s own popover window, which is slow to appear, closes on any click
/// outside it and can't be moved. The panel stays open until it is toggled or closed, keeps the
/// position the user dragged it to, and floats above other apps' windows.
@MainActor
final class MainWindowController: NSObject {
    private var panel: MainPanel?
    private var hostingController: NSViewController?
    private weak var statusButton: NSStatusBarButton?
    private var makeContent: (() -> AnyView)?
    private var hasBeenPositioned = false

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Takes over left-clicks on `statusItem` from `MenuBarExtra`, so they toggle this panel instead
    /// of SwiftUI's popover. Safe to call repeatedly.
    ///
    /// `content` is only evaluated once, when the panel is first shown.
    func attach<Content: View>(to statusItem: NSStatusItem, content: @escaping () -> Content) {
        guard let button = statusItem.button else { return }
        statusButton = button
        makeContent = { AnyView(content()) }
        statusItem.detachExpandedInterfaceDelegate()
        // Normally `RightClickHandlerView` receives the click and calls `toggle()` itself, so the
        // button never sees it. The action is the fallback in case the click is delivered as a
        // button action instead of a mouse event.
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseDown])
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        toggle()
    }

    /// Shows the panel below the status item, or hides it if it is already visible.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func hide() {
        panel?.orderOut(nil)
        statusButton?.highlight(false)
    }

    private func show() {
        guard let button = statusButton else { return }
        guard let panel = panel ?? makeContent.map({ makePanel(content: $0()) }) else { return }
        self.panel = panel

        if !hasBeenPositioned || !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            position(panel, below: button)
            hasBeenPositioned = true
        }

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)
        NotificationCenter.default.post(name: Self.didShowNotification, object: self)
    }

    /// Posted each time the panel is shown, so the UI can reset its initial keyboard focus.
    static let didShowNotification = Notification.Name("MainWindowControllerDidShow")

    private func makePanel<Content: View>(content: Content) -> MainPanel {
        // `onClose` also handles Escape (via `onExitCommand`); `MainPanel.cancelOperation` catches
        // an Escape that reaches the window without SwiftUI handling it.
        let rootView = MainWindowView(
            onClose: { [weak self] in self?.hide() },
            onSizeChange: { [weak self] size in self?.resizePanel(to: size) }
        ) { content }
        let hostingController = NSHostingController(rootView: rootView)
        // The panel is sized only by `resizePanel(to:)`; letting AppKit size the window from the
        // hosting controller as well ends in a resize/layout loop.
        hostingController.sizingOptions = []
        self.hostingController = hostingController
        let initialSize = hostingController.sizeThatFits(in: CGSize(width: CGFloat.infinity, height: .infinity))

        // A hosting view that is the window's content view resizes the window itself after layout,
        // keeping the left edge fixed. Wrapped in a plain container it just fills the container.
        let container = NSView(frame: CGRect(origin: .zero, size: initialSize))
        let hostingView = hostingController.view
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        let panel = MainPanel(
            contentRect: CGRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentView = container
        panel.onCancel = { [weak self] in self?.hide() }
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    /// Fits the panel to the SwiftUI content, keeping its top-right corner in place: it grows downward
    /// like the popover did, and the presets list on the right stays put when the timer side changes.
    ///
    /// Runs synchronously in the layout pass that measured the new size, so the window and its content
    /// change in the same frame instead of the content briefly showing at the old window size. This
    /// can't loop: the content is `fixedSize`, so the window's size doesn't feed back into it.
    private func resizePanel(to size: CGSize) {
        guard let panel, size.width > 0, size.height > 0, panel.frame.size != size else { return }
        let frame = panel.frame
        panel.setFrame(CGRect(x: frame.maxX - size.width, y: frame.maxY - size.height, width: size.width, height: size.height), display: true)
        // The shadow follows the content's rounded shape, which just changed.
        panel.invalidateShadow()
    }

    /// Centers the panel horizontally below the status item, kept inside the screen's visible frame.
    private func position(_ panel: NSPanel, below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let size = panel.frame.size
        let gap: CGFloat = 6

        var origin = CGPoint(x: buttonFrame.midX - size.width / 2, y: buttonFrame.minY - gap - size.height)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + gap), visible.maxX - gap - size.width)
            origin.y = max(origin.y, visible.minY + gap)
        }
        panel.setFrameOrigin(origin)
    }
}

/// A borderless panel that can still become key, so text fields and key handling in the UI work.
final class MainPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Called when Escape reaches the window.
    var onCancel: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
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
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        if event.type == .keyDown, event.keyCode == Self.tabKeyCode, modifiers.isEmpty,
           !(firstResponder is TabKeyHandling) {
            moveFocus(from: firstResponder as? NSView, forward: !event.modifierFlags.contains(.shift))
            return
        }
        super.sendEvent(event)
    }

    /// Virtual key code (`NSEvent.keyCode`) of the Tab key.
    private static let tabKeyCode: UInt16 = 48

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

        let presetsColumnMinX = contentView.bounds.maxX - PresetsListView.width
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

extension NSStatusItem {
    /// Stops a click on a window-based `MenuBarExtra` from presenting SwiftUI's own popover.
    ///
    /// On macOS 27 a left-click on the status item no longer reaches the button as a mouse event.
    /// The system menu bar instead begins an "expanded interface session", and SwiftUI (the
    /// item's `expandedInterfaceDelegate`) shows its window in response. Removing that delegate
    /// stops the session from starting, so the click is delivered to the button again. This is
    /// private API, invoked dynamically, and does nothing on systems that don't have it.
    /// Same approach as MenuBarExtraAccess's `isEnabled: false`, minus disabling the button.
    func detachExpandedInterfaceDelegate() {
        let setDelegate = NSSelectorFromString("setExpandedInterfaceDelegate:")
        guard responds(to: setDelegate) else { return }
        perform(setDelegate, with: nil)
    }
}

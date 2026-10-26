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
}

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

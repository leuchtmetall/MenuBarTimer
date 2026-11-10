//
//  MenuBarAppearance.swift
//  MenuBarTimer
//

import AppKit
import Combine

/// Whether the menu bar currently draws light-on-dark, which depends on the wallpaper behind it as
/// much as on the system appearance.
///
/// The rasterized group label needs this: `ImageRenderer` cannot see the menu bar's appearance, and
/// a template image (which macOS would tint itself) also flattens emoji in timer names to one color.
/// `RightClickHandlerView` sits inside the status item button and reports its effective appearance.
final class MenuBarAppearance: ObservableObject {
    @Published private(set) var isDark = false

    func update(from appearance: NSAppearance) {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        // Only publish real changes: this is called on every status item update.
        if isDark != self.isDark { self.isDark = isDark }
    }
}

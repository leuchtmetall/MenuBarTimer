//
//  TimerColor.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

/// The colors a group timer can have, as stored in `TimerPreset.colorName`:
/// - a palette color, `"<hue>"` or `"<hue>-<shade>"`, e.g. `"blue"` or `"blue-light"`;
/// - a custom color picked in the system color panel, `"#RRGGBB"` in sRGB.
///
/// Plain hue names are what earlier versions stored, so existing groups keep their colors.
enum TimerColor {
    /// The palette's hues, in the order the color picker shows them.
    static let hues: [(name: String, color: Color)] = [
        ("red", .red), ("orange", .orange), ("yellow", .yellow), ("green", .green),
        ("mint", .mint), ("teal", .teal), ("cyan", .cyan), ("blue", .blue),
        ("indigo", .indigo), ("purple", .purple), ("pink", .pink), ("brown", .brown),
        ("gray", .gray),
    ]

    /// The brightness variants of each hue, lightest first.
    enum Shade: String, CaseIterable {
        case lighter, light, base, dark

        fileprivate func apply(to color: Color) -> Color {
            switch self {
            case .lighter: color.mix(with: .white, by: 0.5)
            case .light: color.mix(with: .white, by: 0.25)
            case .base: color
            case .dark: color.mix(with: .black, by: 0.3)
            }
        }
    }

    /// The stored name of a palette color.
    static func name(hue: String, shade: Shade) -> String {
        shade == .base ? hue : "\(hue)-\(shade.rawValue)"
    }

    /// The color a stored name stands for, or `nil` for no color or a name that isn't recognized.
    static func color(named name: String?) -> Color? {
        guard let name else { return nil }
        if name.hasPrefix("#") { return customColor(hex: name) }

        let parts = name.split(separator: "-", maxSplits: 1).map(String.init)
        guard let hue = hues.first(where: { $0.name == parts[0] })?.color else { return nil }
        guard parts.count == 2 else { return hue }
        return Shade(rawValue: parts[1])?.apply(to: hue)
    }

    static func isCustom(_ name: String?) -> Bool {
        name?.hasPrefix("#") == true
    }

    /// The stored name of a custom color: its sRGB value as `"#RRGGBB"`. Alpha is dropped.
    static func customName(for color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? .black
        func byte(_ component: CGFloat) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(srgb.redComponent), byte(srgb.greenComponent), byte(srgb.blueComponent))
    }

    private static func customColor(hex: String) -> Color? {
        let digits = hex.dropFirst()
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

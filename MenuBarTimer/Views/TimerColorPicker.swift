//
//  TimerColorPicker.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

/// A group timer's color swatch with a dropdown chevron. Clicking it opens a popover with the
/// `TimerColor` palette (one column per hue, lightest shade at the top), "no color", and a custom
/// option that opens the system color panel. A timer without a color is drawn in the menu bar's
/// default color.
struct TimerColorPicker: View {
    @Binding var colorName: String?
    /// Identifies this picker to the shared color panel, so only the picker that opened it receives its changes.
    let ownerID: UUID
    @State private var isPresented = false

    private static let swatchSize: CGFloat = 16
    private static let swatchSpacing: CGFloat = 4

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                ColorSwatch(colorName: colorName, shape: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .frame(width: 18, height: 12)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .frame(height: 20)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Timer color")
        .accessibilityLabel("Timer color")
        .accessibilityValue(accessibilityName(for: colorName))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            palette
                .padding(10)
        }
        // The panel would otherwise keep editing this timer after the editor is gone.
        .onDisappear { ColorPanelController.shared.detach(ownerID) }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: Self.swatchSpacing) {
                ForEach(TimerColor.hues, id: \.name) { hue in
                    VStack(spacing: Self.swatchSpacing) {
                        ForEach(TimerColor.Shade.allCases, id: \.self) { shade in
                            option(TimerColor.name(hue: hue.name, shade: shade))
                        }
                    }
                }
            }

            HStack {
                optionButton(isSelected: colorName == nil, help: "No color") {
                    colorName = nil
                    isPresented = false
                } label: {
                    HStack(spacing: 5) {
                        swatch(nil)
                        Text("None")
                    }
                }

                Spacer()

                optionButton(isSelected: TimerColor.isCustom(colorName), help: "Choose a custom color") {
                    openColorPanel()
                } label: {
                    HStack(spacing: 5) {
                        Text("Custom…")
                        RainbowSwatch()
                            .frame(width: Self.swatchSize, height: Self.swatchSize)
                    }
                }
            }
            .font(.callout)
        }
    }

    private func option(_ name: String) -> some View {
        optionButton(isSelected: name == colorName, help: accessibilityName(for: name)) {
            colorName = name
            isPresented = false
        } label: {
            swatch(name)
        }
    }

    private func swatch(_ name: String?) -> some View {
        ColorSwatch(colorName: name, shape: Circle())
            .frame(width: Self.swatchSize, height: Self.swatchSize)
    }

    private func optionButton(
        isSelected: Bool,
        help: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: action) {
            label()
                .padding(2)
                .overlay {
                    if isSelected {
                        Capsule().strokeBorder(.primary, lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func openColorPanel() {
        isPresented = false
        let binding = $colorName
        let initial = TimerColor.color(named: colorName).map(NSColor.init) ?? .systemBlue
        ColorPanelController.shared.open(for: ownerID, initialColor: initial) { color in
            binding.wrappedValue = TimerColor.customName(for: color)
        }
    }

    private func accessibilityName(for name: String?) -> String {
        guard let name else { return "No color" }
        if TimerColor.isCustom(name) { return "Custom color \(name)" }
        return name.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

/// A shape filled with a timer color, or outlined and struck through for no color.
private struct ColorSwatch<S: InsettableShape>: View {
    let colorName: String?
    let shape: S

    var body: some View {
        if let color = TimerColor.color(named: colorName) {
            shape.fill(color)
                .overlay { shape.strokeBorder(.primary.opacity(0.15), lineWidth: 0.5) }
        } else {
            shape.strokeBorder(.secondary, lineWidth: 1)
                .background {
                    GeometryReader { proxy in
                        Path { path in
                            path.move(to: CGPoint(x: proxy.size.width, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                        }
                        .stroke(.secondary, lineWidth: 1)
                    }
                }
                .clipShape(shape)
        }
    }
}

/// The custom color option's swatch: a circle filled with a hue wheel.
private struct RainbowSwatch: View {
    var body: some View {
        Circle()
            .fill(AngularGradient(
                colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                center: .center
            ))
    }
}

/// Lends the shared `NSColorPanel` to one color picker at a time.
///
/// The panel floats above the main panel (itself `.floating`), which would otherwise cover it.
/// Its changes are delivered continuously while the user drags in it.
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var ownerID: UUID?
    private var onChange: ((NSColor) -> Void)?

    func open(for ownerID: UUID, initialColor: NSColor, onChange: @escaping (NSColor) -> Void) {
        let panel = NSColorPanel.shared
        // Detach first: setting the color sends the action, which mustn't reach the previous owner.
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = initialColor

        self.ownerID = ownerID
        self.onChange = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))

        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        NSApp.activate()
        panel.orderFront(nil)
    }

    /// Stops sending changes to `ownerID` and closes the panel, if that picker is the one using it.
    func detach(_ ownerID: UUID) {
        guard self.ownerID == ownerID else { return }
        self.ownerID = nil
        onChange = nil
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.orderOut(nil)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}

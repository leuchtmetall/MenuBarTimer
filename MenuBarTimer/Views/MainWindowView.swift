//
//  MainWindowView.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

/// The chrome of the main panel: a rounded, translucent background like the old `MenuBarExtra`
/// popover, plus a close button in the top-left corner.
struct MainWindowView<Content: View>: View {
    let onClose: () -> Void
    /// Reports the content's natural size, which the window is fitted to.
    let onSizeChange: (CGSize) -> Void
    @ViewBuilder let content: Content

    private let cornerRadius: CGFloat = 16

    var body: some View {
        content
            .background {
                VisualEffectBackground()
                    .gesture(WindowDragGesture())
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .overlayPreferenceValue(PresetsHeaderBoundsKey.self) { header in
                // Vertically centered on the presets header row, so it lines up with Edit and the
                // ellipsis menu. Styled and sized like the ellipsis menu button.
                GeometryReader { proxy in
                    let midY = header.map { proxy[$0].midY } ?? 24 + closeButtonSize / 2
                    closeButton
                        .position(x: 24 + closeButtonSize / 2, y: midY)
                }
            }
            .onExitCommand(perform: onClose)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
            .modifier(TopTrailingPinned())
    }

    private let closeButtonSize: CGFloat = 23

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .frame(width: 13, height: 13)
                .padding(5)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .frame(width: closeButtonSize, height: closeButtonSize)
        .help("Close")
        .accessibilityLabel("Close")
    }
}

/// Pins the content to the top-right corner of the hosting view instead of centering it.
///
/// The window keeps its top-right corner fixed when it resizes, so if a frame is ever drawn with the
/// new content in the old window size, the content already sits where it ends up.
private struct TopTrailingPinned: ViewModifier {
    func body(content: Content) -> some View {
        TopTrailingLayout { content }
    }
}

private struct TopTrailingLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let childSize = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        // Fill a concrete proposal (the hosting view's bounds); otherwise, e.g. when the panel
        // measures its initial size, report the content's own size.
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite else { return childSize }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.maxX, y: bounds.minY), anchor: .topTrailing, proposal: .unspecified)
    }
}

/// The bounds of the presets list's header row, which the close button aligns with.
struct PresetsHeaderBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

//
//  MenuBarLabelView.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

/// The compact view shown in the macOS menu bar.
///
/// `MenuBarExtra` only reliably renders `Text` and `Image` content in its label;
/// arbitrary `Shape`-based views (like our progress indicator) are silently dropped.
/// To work around that, the indicator is rasterized to a template `NSImage` and shown
/// via `Image`. Rendering it as a template image also means macOS automatically tints
/// it to match the current menu bar foreground color, keeping it visible in both
/// light and dark mode.
struct MenuBarLabelView: View {
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var presetsStore: PresetsStore

    private let iconSize: CGFloat = 18

    var body: some View {
        HStack() {
            Image(nsImage: ringImage)
                .frame(width: iconSize, height: iconSize)
            Text(timerModel.remaining.formattedClock)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
        .onAppear {
            // Restore the previously selected timer on launch (or a reasonable default on first launch).
            guard timerModel.totalDuration == 0, let seconds = presetsStore.selectedPreset?.seconds else { return }
            timerModel.load(seconds: seconds)
        }
    }

    private var ringImage: NSImage {
        let renderer = ImageRenderer(content:
            PieProgressView(progress: timerModel.progress)
                .padding(1)
                .frame(width: iconSize, height: iconSize)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        renderer.proposedSize = ProposedViewSize(width: iconSize, height: iconSize)
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: iconSize, height: iconSize))
        image.isTemplate = true
        return image
    }
}

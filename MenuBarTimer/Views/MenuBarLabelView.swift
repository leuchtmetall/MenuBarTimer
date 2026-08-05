//
//  MenuBarLabelView.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

/// The compact view shown in the macOS menu bar.
///
/// `MenuBarExtra` reliably renders a single `Text` or `Image` label. Group labels are
/// therefore composed into one `Text` value rather than a dynamic view hierarchy.
///
/// Because of that flattening, the view also measures how wide each group timer's part of the
/// label is and reports it to `layout`, which is what lets a right-click on the status item be
/// attributed to the timer under the cursor (see `MenuBarTimerApp`).
struct MenuBarLabelView: View {
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var groupsStore: TimerGroupsStore
    @ObservedObject var groupCoordinator: TimerGroupCoordinator
    @ObservedObject var settings: AppSettings
    let layout: MenuBarLabelLayout

    private let iconSize: CGFloat = 18
    /// Separates two timers in the plain-text group label.
    private static let groupLabelSeparator = "   "

    var body: some View {
        Group {
            if let groupModel = groupCoordinator.model {
                if settings.useGroupTimerColors {
                    Image(nsImage: coloredGroupLabelImage(for: groupModel))
                } else {
                    groupLabel(for: groupModel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            } else {
                HStack {
                    timerImage(for: timerModel)
                    Text(timerModel.timeString)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                }
                .onAppear { layout.clear() }
            }
        }
        .onAppear {
            groupCoordinator.load(groupsStore.selectedGroup)
            // Restore the previously selected timer on launch (or a reasonable default on first launch).
            guard !timerModel.hasLoadedTimer, let preset = presetsStore.selectedPreset else { return }
            timerModel.load(preset)
        }
        .onChange(of: groupsStore.selectedGroupID) { _, _ in
            groupCoordinator.load(groupsStore.selectedGroup)
        }
        .onChange(of: groupsStore.groups) { _, _ in
            groupCoordinator.load(groupsStore.selectedGroup)
        }
    }

    private func timerImage(for timerModel: TimerModel) -> some View {
        var img: Image;
        if (timerModel.preset.isStopwatch) {
            img = Image(systemName: "stopwatch")
        } else {
            img = Image(nsImage: ringImage(progress: timerModel.progress))
        }
        return img.frame(width: iconSize, height: iconSize)
    }

    /// The name prefix shown for a group timer, per the current display setting.
    private func displayName(for timerModel: TimerModel) -> String {
        let timerName = timerModel.preset.name ?? ""
        switch settings.groupTimerNameDisplay {
        case .wholeLabel: return timerName
        case .firstCharacter: return String(timerName.prefix(1))
        case .none: return ""
        }
    }

    /// The text of every timer in the plain-text group label, paired with its `TimerPreset.id`.
    /// Shared by the label itself and by its measurement so the two cannot drift apart.
    private func groupLabelSegments(for groupModel: TimerGroupModel) -> [(id: UUID, text: String)] {
        groupModel.timerModels.map { timerModel in
            let name = displayName(for: timerModel)
            // TODO improve check for group-timer
            let prefix = settings.groupTimerNameDisplay == .none ? "" : name + " "
            return (timerModel.preset.id, prefix + timerModel.timeString)
        }
    }

    private func groupLabel(for groupModel: TimerGroupModel) -> Text {
        let segments = groupLabelSegments(for: groupModel)
        let text = segments.map(\.text).joined(separator: Self.groupLabelSeparator)

        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        layout.update(
            segments: MenuBarLabelLayout.distribute(
                ids: segments.map(\.id),
                widths: segments.map { textWidth(of: $0.text, font: font) },
                gap: textWidth(of: Self.groupLabelSeparator, font: font)
            ),
            contentWidth: textWidth(of: text, font: font)
        )

        return Text(text)
    }

    private func coloredGroupLabelImage(for groupModel: TimerGroupModel) -> NSImage {
        let items = groupModel.timerModels.map { timerModel in
            GroupTimerLabelItem(
                name: displayName(for: timerModel),
                timeString: timerModel.timeString,
                color: timerModel.preset.color,
                isStopwatch: timerModel.preset.isStopwatch,
                progress: timerModel.progress,
                showProgress: settings.showGroupTimerProgress,
                ringImage: ringImage
            )
        }

        let renderer = ImageRenderer(content: ColoredGroupMenuBarLabel(items: items))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: .zero)
        image.isTemplate = false

        layout.update(
            segments: MenuBarLabelLayout.distribute(
                ids: groupModel.timerModels.map { $0.preset.id },
                widths: items.map { viewWidth(of: $0) },
                gap: ColoredGroupMenuBarLabel.spacing,
                leadingInset: ColoredGroupMenuBarLabel.leadingPadding
            ),
            contentWidth: image.size.width
        )

        return image
    }

    private func ringImage(progress: Double) -> NSImage {
        let renderer = ImageRenderer(content:
            PieProgressView(progress: progress)
                .padding(1)
                .frame(width: iconSize, height: iconSize)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        renderer.proposedSize = ProposedViewSize(width: iconSize, height: iconSize)
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: iconSize, height: iconSize))
        image.isTemplate = true
        return image
    }

    private func textWidth(of string: String, font: NSFont) -> CGFloat {
        NSAttributedString(string: string, attributes: [.font: font]).size().width
    }

    /// Lays a view out without rasterizing it, purely to learn how wide it is.
    private func viewWidth<Content: View>(of content: Content) -> CGFloat {
        var width: CGFloat = 0
        ImageRenderer(content: content).render { size, _ in width = size.width }
        return width
    }
}

private struct ColoredGroupMenuBarLabel: View {
    static let spacing: CGFloat = 12
    static let leadingPadding: CGFloat = 4

    let items: [GroupTimerLabelItem]

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                item
            }
        }
        .fixedSize()
        .padding(.leading, Self.leadingPadding)
    }
}

/// One timer inside the colored group label. Rendered as part of the label and, separately,
/// laid out on its own to measure the width of that timer's segment.
private struct GroupTimerLabelItem: View {
    let name: String
    let timeString: String
    let color: Color
    let isStopwatch: Bool
    let progress: Double
    let showProgress: Bool
    let ringImage: (Double) -> NSImage

    var body: some View {
        HStack(spacing: 2) {
            Text(name).padding(.top, -2).padding(.leading, -4)
            if showProgress {
                if isStopwatch {
                    Image(systemName: "stopwatch")
                } else {
                    Image(nsImage: ringImage(progress))
                }
            }
            Text(timeString)
                .monospacedDigit()
                .padding(.top, -2)
                .padding(.trailing, 1)
                .padding(.leading, -0.5)
        }
        .font(Font(NSFont.menuBarFont(ofSize: 0)))
        .foregroundStyle(color)
        .padding(.trailing, 1)
    }
}

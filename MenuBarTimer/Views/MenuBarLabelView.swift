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
struct MenuBarLabelView: View {
    @ObservedObject var timerModel: TimerModel
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var groupsStore: TimerGroupsStore
    @ObservedObject var groupCoordinator: TimerGroupCoordinator
    @ObservedObject var settings: AppSettings

    private let iconSize: CGFloat = 18

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
                    Text(timerModel.preset.type == .countUp ? timerModel.remaining.formattedElapsedClock : timerModel.remaining.formattedClock)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                }
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
        if (timerModel.preset.type == .countUp) {
            img = Image(systemName: "stopwatch")
        } else {
            img = Image(nsImage: ringImage(progress: timerModel.progress))
        }
        return img.frame(width: iconSize, height: iconSize)
    }

    private func groupLabel(for groupModel: TimerGroupModel) -> Text {
        var label = Text("")
        for (index, definition) in groupModel.group.timers.enumerated() {
            let timer = groupModel.timerModels[index]
            let icon = timer.preset.type == .countUp
                ? Image(systemName: "stopwatch")
                : Image(nsImage: ringImage(progress: timer.progress))
//            let icon = timerImage(for: timerModel)
            let time = timer.preset.type == .countUp
                ? timer.remaining.formattedElapsedClock
                : timer.remaining.formattedClock
            let timerName = definition.name ?? ""
            let name: String = switch settings.groupTimerNameDisplay {
            case .wholeLabel: timerName + " " // TODO improve check for group-timer
            case .firstCharacter: String(timerName.prefix(1)) + " "
            case .none: ""
            }
            var segment = Text(name)
            if settings.showGroupTimerProgress {
                segment = segment + Text(icon) + Text(" ")
            }
            segment = segment + Text(time)
            if index > 0 { label = label + Text("   ") }
            label = label + segment
        }
        return label
    }

    private func coloredGroupLabelImage(for groupModel: TimerGroupModel) -> NSImage {
        let renderer = ImageRenderer(content: ColoredGroupMenuBarLabel(
            group: groupModel.group,
            timers: groupModel.timerModels,
            nameDisplay: settings.groupTimerNameDisplay,
            showProgress: settings.showGroupTimerProgress,
            ringImage: ringImage
        ))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: .zero)
        image.isTemplate = false
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
}

private struct ColoredGroupMenuBarLabel: View {
    let group: TimerGroup
    let timers: [TimerModel]
    let nameDisplay: GroupTimerNameDisplay
    let showProgress: Bool
    let ringImage: (Double) -> NSImage

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(zip(group.timers.indices, group.timers)), id: \.1.id) { index, definition in
                let timer = timers[index]
                let timerName = definition.name ?? "" // TODO?
                let name: String = switch nameDisplay {
                case .wholeLabel: timerName
                case .firstCharacter: String(timerName.prefix(1))
                case .none: ""
                }
                HStack(spacing: 2) {
                    Text(name)
                    if showProgress {
                        if timer.preset.type == .countUp {
                            Image(systemName: "stopwatch")
                        } else {
                            Image(nsImage: ringImage(timer.progress))
                        }
                    }
                    Text(timer.preset.type == .countUp ? timer.remaining.formattedElapsedClock : timer.remaining.formattedClock)
                       .monospacedDigit()
                }
                .font(Font(NSFont.menuBarFont(ofSize: 0)))
               .font(.system(size: 13, weight: .medium))
                .foregroundStyle(definition.color)
            }
        }
        .fixedSize()
    }
}

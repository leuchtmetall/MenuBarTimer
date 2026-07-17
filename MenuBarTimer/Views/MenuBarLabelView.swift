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
                    Text(timerModel.timeString)
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
        if (timerModel.preset.isStopwatch) {
            img = Image(systemName: "stopwatch")
        } else {
            img = Image(nsImage: ringImage(progress: timerModel.progress))
        }
        return img.frame(width: iconSize, height: iconSize)
    }

    private func groupLabel(for groupModel: TimerGroupModel) -> Text {
        let labels = groupModel.timerModels.map {timerModel -> String in
            let timerName = timerModel.preset.name ?? ""
            let name: String = switch settings.groupTimerNameDisplay {
                case .wholeLabel: timerName + " " // TODO improve check for group-timer
                case .firstCharacter: String(timerName.prefix(1)) + " "
                case .none: ""
            }
            return name + timerModel.timeString
        }
        return Text(labels.joined(separator: "   "))
    }
    
    private func coloredGroupLabelImage(for groupModel: TimerGroupModel) -> NSImage {
        let renderer = ImageRenderer(content: ColoredGroupMenuBarLabel(
            timerModels: groupModel.timerModels,
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
    let timerModels: [TimerModel]
    let nameDisplay: GroupTimerNameDisplay
    let showProgress: Bool
    let ringImage: (Double) -> NSImage

    var body: some View {
        HStack(spacing: 12) {
            ForEach(timerModels) { timerModel in
                let timerName = timerModel.preset.name ?? "" // TODO?
                let name: String = switch nameDisplay {
                case .wholeLabel: timerName
                case .firstCharacter: String(timerName.prefix(1))
                case .none: ""
                }
                HStack(spacing: 2) {
                    Text(name).padding(.top, -2).padding(.leading, -4)
                    if showProgress {
                        if timerModel.preset.isStopwatch {
                            Image(systemName: "stopwatch")
                        } else {
                            Image(nsImage: ringImage(timerModel.progress))
                        }
                    }
                    Text(timerModel.timeString)
                       .monospacedDigit()
                       .padding(.top, -2)
                       .padding(.trailing, 1)
                       .padding(.leading, -0.5)
                }
                .font(Font(NSFont.menuBarFont(ofSize: 0)))
                .foregroundStyle(timerModel.preset.color)
                .padding(.trailing, 1)
            }
        }
        .fixedSize()
        .padding(.leading, 4)
    }
}

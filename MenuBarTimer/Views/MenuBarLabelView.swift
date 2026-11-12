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
    @ObservedObject var menuBarAppearance: MenuBarAppearance
    let layout: MenuBarLabelLayout

    private let iconSize: CGFloat = 18
    /// Progress ring size in the compact rasterized group label.
    private let compactIconSize: CGFloat = 14
    /// Separates two timers in the plain-text group label.
    private static let groupLabelSeparator = "   "

    var body: some View {
        Group {
            if let groupModel = groupCoordinator.model {
                // Colors, progress rings, the compact layout and the dots for hidden timers all need
                // the rasterized label; plain `Text` can do none of them.
                if settings.useGroupTimerColors || settings.showGroupTimerProgress || settings.useCompactColoredLabels
                    || reducedTimersShowProgress || hasHiddenTimerDots(for: groupModel) {
                    Image(nsImage: groupLabelImage(for: groupModel, useColors: settings.useGroupTimerColors))
                } else {
                    groupLabel(for: groupModel)
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
        let image = timerModel.preset.isStopwatch
            ? Image(systemName: "stopwatch")
            : Image(nsImage: ProgressRingImage.image(progress: timerModel.progress, size: iconSize))
        return image.frame(width: iconSize, height: iconSize)
    }

    /// The name prefix shown for a group timer, per the current display setting.
    private func displayName(for timerModel: TimerModel) -> String {
        let timerName = timerModel.preset.name
        switch settings.groupTimerNameDisplay {
        case .wholeLabel: return timerName
        case .firstCharacter: return String(timerName.prefix(1))
        case .none: return ""
        }
    }

    /// A group timer in the label. In compact mode every timer but the active one is reduced to
    /// what `settings.compactInactiveTimerDisplay` asks for.
    private struct DisplayedTimer {
        let model: TimerModel
        let isReduced: Bool
    }

    /// The group timers shown in the label, in group order: all of them in full, or in compact mode
    /// the active one in full and the others reduced (or left out).
    private func displayedTimers(for groupModel: TimerGroupModel) -> [DisplayedTimer] {
        let models = groupModel.timerModels
        guard settings.showOnlyActiveGroupTimer else {
            return models.map { DisplayedTimer(model: $0, isReduced: false) }
        }
        guard let active = activeTimer(in: groupModel) else { return [] }
        switch settings.compactInactiveTimerDisplay {
        case .none, .dots:
            // Dots are not timers in the label: they are drawn around it (see `hiddenTimers`).
            return [DisplayedTimer(model: active, isReduced: false)]
        case .name, .nameAndProgress, .nameAndTime:
            break
        }
        return models.map { DisplayedTimer(model: $0, isReduced: $0 !== active) }
    }

    /// The timer compact mode draws in full: the group's active one, or the first while none is.
    private func activeTimer(in groupModel: TimerGroupModel) -> TimerModel? {
        let models = groupModel.timerModels
        return models.first(where: { $0.preset.id == groupModel.activeTimerID }) ?? models.first
    }

    /// The timers compact mode replaces with a dot (`CompactInactiveTimerDisplay.dots`), so it is
    /// still visible that the group has more timers. The dots keep the group's order: timers before
    /// the active one are drawn before it, the others after it. Each side is capped at
    /// `HiddenTimerDots.maxCount`, keeping the timers closest to the active one.
    private func hiddenTimers(for groupModel: TimerGroupModel) -> (leading: [TimerModel], trailing: [TimerModel]) {
        let models = groupModel.timerModels
        guard settings.showOnlyActiveGroupTimer, settings.compactInactiveTimerDisplay == .dots,
              let active = activeTimer(in: groupModel),
              let activeIndex = models.firstIndex(where: { $0 === active }) else { return ([], []) }
        return (
            Array(models[..<activeIndex].suffix(HiddenTimerDots.maxCount)),
            Array(models[(activeIndex + 1)...].prefix(HiddenTimerDots.maxCount))
        )
    }

    /// Dots need the rasterized label even if nothing else does.
    private func hasHiddenTimerDots(for groupModel: TimerGroupModel) -> Bool {
        let hidden = hiddenTimers(for: groupModel)
        return !hidden.leading.isEmpty || !hidden.trailing.isEmpty
    }

    /// Reduced timers with a progress circle need the rasterized label even if nothing else does.
    private var reducedTimersShowProgress: Bool {
        settings.showOnlyActiveGroupTimer && settings.compactInactiveTimerDisplay == .nameAndProgress
    }

    /// The name of a reduced timer. A name-only timer with names hidden would draw nothing at all,
    /// so it falls back to the first character.
    private func reducedName(for timerModel: TimerModel) -> String {
        let name = displayName(for: timerModel)
        guard name.isEmpty, settings.compactInactiveTimerDisplay == .name else { return name }
        return String(timerModel.preset.name.prefix(1))
    }

    /// The text of every timer in the plain-text group label, paired with its `TimerPreset.id`.
    /// Shared by the label itself and by its measurement so the two cannot drift apart.
    private func groupLabelSegments(for groupModel: TimerGroupModel) -> [(id: UUID, text: String)] {
        displayedTimers(for: groupModel).map { timer in
            let timerModel = timer.model
            let name = timer.isReduced ? reducedName(for: timerModel) : displayName(for: timerModel)
            // The plain-text label is never used for `.nameAndProgress` (see `body`).
            guard !timer.isReduced || settings.compactInactiveTimerDisplay == .nameAndTime else {
                return (timerModel.preset.id, name)
            }
            let prefix = name.isEmpty ? "" : name + " "
            return (timerModel.preset.id, prefix + timerModel.timeString)
        }
    }

    private func groupLabel(for groupModel: TimerGroupModel) -> Text {
        let segments = groupLabelSegments(for: groupModel)
        let text = segments.map(\.text).joined(separator: Self.groupLabelSeparator)

        // Measure in the font the status item actually draws the title in (see `body`).
        let font = NSFont.menuBarFont(ofSize: 0)
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

    /// The rasterized group label. Timers without a color (all of them when colors are off) are
    /// drawn in the menu bar's own text color, taken from `menuBarAppearance` because `ImageRenderer`
    /// cannot see it. The image is deliberately not a template: that would tint emoji in timer
    /// names as well.
    private func groupLabelImage(for groupModel: TimerGroupModel, useColors: Bool) -> NSImage {
        let defaultColor: Color = menuBarAppearance.isDark ? .white : .black
        let isCompact = settings.useCompactColoredLabels
        let ringSize = isCompact ? compactIconSize : iconSize
        let timers = displayedTimers(for: groupModel)
        let reducedDisplay = settings.compactInactiveTimerDisplay
        let items = timers.map { timer in
            let timerModel = timer.model
            return GroupTimerLabelItem(
                name: timer.isReduced ? reducedName(for: timerModel) : displayName(for: timerModel),
                timeString: timerModel.timeString,
                color: (useColors ? TimerColor.color(named: timerModel.preset.colorName) : nil) ?? defaultColor,
                isStopwatch: timerModel.preset.isStopwatch,
                progress: timerModel.progress,
                isActive: timerModel.state == .running,
                showProgress: timer.isReduced ? reducedDisplay == .nameAndProgress : settings.showGroupTimerProgress,
                showTime: !timer.isReduced || reducedDisplay == .nameAndTime,
                isCompact: isCompact,
                ringSize: ringSize
            )
        }

        // Hidden timers without a color get a dimmed dot, so the dots read as secondary to the time.
        let dotColor: (TimerModel) -> Color = { timerModel in
            (useColors ? TimerColor.color(named: timerModel.preset.colorName) : nil) ?? defaultColor.opacity(0.5)
        }
        let hidden = hiddenTimers(for: groupModel)
        let label = ColoredGroupMenuBarLabel(
            items: items,
            leadingDotColors: hidden.leading.map(dotColor),
            trailingDotColors: hidden.trailing.map(dotColor)
        )
        let renderer = ImageRenderer(content: label)
        renderer.scale = NSScreen.highestBackingScaleFactor
        let image = renderer.nsImage ?? NSImage(size: .zero)
        image.isTemplate = false

        layout.update(
            segments: MenuBarLabelLayout.distribute(
                ids: timers.map { $0.model.preset.id },
                widths: items.map { item in layout.width(for: item.widthKey) { viewWidth(of: item) } },
                gap: ColoredGroupMenuBarLabel.spacing,
                // The dots belong to the segment of the (only) timer they surround.
                leadingInset: ColoredGroupMenuBarLabel.leadingPadding
                    + ColoredGroupMenuBarLabel.leadingDotsWidth(count: hidden.leading.count),
                trailingInset: ColoredGroupMenuBarLabel.trailingDotsWidth(count: hidden.trailing.count)
            ),
            contentWidth: image.size.width
        )

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
    static let verticalPadding: CGFloat = 2

    /// Between the timers and the dots for hidden timers after them. Wide enough to clear the
    /// running timer's background, which overhangs the item.
    static let trailingDotsGap: CGFloat = 6
    /// Between the dots for hidden timers and the timers after them. Wider than the trailing gap
    /// because an item draws its name (and background) 4pt to the left of its own frame.
    static let leadingDotsGap: CGFloat = 10

    let items: [GroupTimerLabelItem]
    /// One dot per timer that compact mode hides, split by whether the timer comes before or after
    /// the active one in the group. Both are empty in every other mode.
    var leadingDotColors: [Color] = []
    var trailingDotColors: [Color] = []

    /// The width the dots before the timers add to the label, including the gap after them.
    static func leadingDotsWidth(count: Int) -> CGFloat {
        count > 0 ? HiddenTimerDots.width(count: count) + leadingDotsGap : 0
    }

    /// The width the dots after the timers add to the label, including the gap before them.
    static func trailingDotsWidth(count: Int) -> CGFloat {
        count > 0 ? trailingDotsGap + HiddenTimerDots.width(count: count) : 0
    }

    var body: some View {
        HStack(spacing: 0) {
            if !leadingDotColors.isEmpty {
                HiddenTimerDots(colors: leadingDotColors)
                    .padding(.trailing, Self.leadingDotsGap)
            }
            HStack(spacing: Self.spacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    item
                }
            }
            if !trailingDotColors.isEmpty {
                HiddenTimerDots(colors: trailingDotColors)
                    .padding(.leading, Self.trailingDotsGap)
            }
        }
        .fixedSize()
        .padding(.leading, Self.leadingPadding)
        // `ImageRenderer` clips to the view's bounds. The items pull their text up with negative
        // top padding, which lets tall emoji glyphs (e.g. 👦🏻, 💼) poke out above the label and get
        // cut off. Symmetric headroom keeps them in the image without moving the label off-center.
        .padding(.vertical, Self.verticalPadding)
    }
}

/// The indicator for the timers compact mode hides: one small dot each, in the timer's color.
private struct HiddenTimerDots: View {
    /// More hidden timers than this on one side of the active timer still get only this many dots,
    /// to keep the label short.
    static let maxCount = 5
    static let dotSize: CGFloat = 4
    static let spacing: CGFloat = 2

    let colors: [Color]

    static func width(count: Int) -> CGFloat {
        count > 0 ? CGFloat(count) * dotSize + CGFloat(count - 1) * spacing : 0
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle().fill(color).frame(width: Self.dotSize, height: Self.dotSize)
            }
        }
        // The timers pull their text up by the same amount.
        .offset(y: -1)
    }
}

/// One timer inside the rasterized group label. Rendered as part of the label and, separately,
/// laid out on its own to measure the width of that timer's segment.
private struct GroupTimerLabelItem: View {
    let name: String
    let timeString: String
    let color: Color
    let isStopwatch: Bool
    let progress: Double
    /// The running timer gets a tinted background so it stands out from the paused ones.
    let isActive: Bool
    let showProgress: Bool
    /// `false` for a reduced timer in compact mode that shows only its name (and circle).
    let showTime: Bool
    let isCompact: Bool
    let ringSize: CGFloat

    /// Everything the item's width depends on, so `MenuBarLabelLayout` can reuse a measured width.
    /// Color, progress and `isActive` don't affect it, and neither do the digits of the time, which
    /// are monospaced: only its shape (`00:00`, `0:00:00`) matters.
    struct WidthKey: Hashable {
        let name: String
        let timeShape: String
        let isStopwatch: Bool
        let showProgress: Bool
        let isCompact: Bool
        let ringSize: CGFloat
    }

    var widthKey: WidthKey {
        WidthKey(
            name: name,
            timeShape: showTime ? String(timeString.map { $0.isNumber ? "0" : $0 }) : "",
            isStopwatch: isStopwatch,
            showProgress: showProgress,
            isCompact: isCompact,
            ringSize: ringSize
        )
    }

    private static let font = NSFont.menuBarFont(ofSize: 0)
    /// Seconds are shrunk in compact mode once hours are visible, to save menu bar space.
    private static let compactSecondsFont = NSFont.menuBarFont(ofSize: font.pointSize * 0.75)

    var body: some View {
        HStack(spacing: 2) {
           Text(name).padding(.top, -2).padding(.leading, -4)
            if showProgress {
                if isStopwatch {
                    Image(systemName: "stopwatch")
                } else {
                    Image(nsImage: ProgressRingImage.image(progress: progress, size: ringSize))
                }
            }
            if showTime {
                timeText
                    .monospacedDigit()
                    .padding(.top, -2)
                    .padding(.trailing, 1)
                    .padding(.leading, -0.5)
            }
        }
        .font(Font(Self.font))
        .foregroundStyle(color)
        .padding(.trailing, 1)
        // A background never changes the item's size, so the right-click hit-testing widths
        // measured in `MenuBarLabelView` stay valid.
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color.opacity(0.2))
                    .padding(.horizontal, -3)
                    .offset(x: -1, y: -1)
            }
        }
    }

    /// `h:mm:ss` is split into `h:mm` + `:ss` in compact mode so the seconds can be set smaller.
    /// Concatenated `Text` shares a baseline, so the smaller seconds sit on the same line.
    private var timeText: Text {
        guard isCompact,
              timeString.filter({ $0 == ":" }).count == 2,
              let secondsStart = timeString.lastIndex(of: ":") else {
            return Text(timeString)
        }
        let hoursAndMinutes = Text(timeString[..<secondsStart])
        let seconds = Text(timeString[secondsStart...])
            .font(Font(Self.compactSecondsFont))
            .monospacedDigit()
        return Text("\(hoursAndMinutes)\(seconds)")
    }
}

#Preview("Colored group label: regular vs compact") {
    let item: (Bool, String) -> GroupTimerLabelItem = { isCompact, time in
        GroupTimerLabelItem(
            name: "W", timeString: time, color: .blue, isStopwatch: false, progress: 0.3, isActive: false,
            showProgress: true, showTime: true, isCompact: isCompact, ringSize: isCompact ? 14 : 18
        )
    }
    VStack(alignment: .leading, spacing: 8) {
        HStack { item(false, "1:23:45"); item(false, "12:34") }
        HStack { item(true, "1:23:45"); item(true, "12:34") }
        ColoredGroupMenuBarLabel(items: [item(false, "12:34")], leadingDotColors: [.orange], trailingDotColors: [.green, .purple])
        ColoredGroupMenuBarLabel(items: [item(true, "12:34")], trailingDotColors: Array(repeating: .primary.opacity(0.5), count: 5))
        ColoredGroupMenuBarLabel(items: [item(true, "12:34")], leadingDotColors: Array(repeating: .primary.opacity(0.5), count: 2))
    }
    .padding()
}

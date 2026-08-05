//
//  MenuBarLabelLayout.swift
//  MenuBarTimer
//

import Foundation

/// Where each group timer ended up horizontally inside the menu bar label.
///
/// In group mode the whole label collapses into a single `Text` or a single rasterized `NSImage`
/// (see `MenuBarLabelView`), so there is no per-timer view a click could land on. `MenuBarLabelView`
/// therefore records the width of every timer's segment as it builds the label, and
/// `timerID(atX:boundsWidth:)` maps a right-click on the status item button back to one timer.
///
/// This is deliberately **not** an `ObservableObject`: it is written from inside the label's view
/// body evaluation, and publishing from there would re-invalidate the view that just wrote it.
/// Nothing observes it — the right-click handler only ever reads it, outside of any view update.
final class MenuBarLabelLayout {
    /// One timer's horizontal slice of the label, in points, left to right.
    struct Segment: Equatable {
        /// The `TimerPreset.id` of the group timer, i.e. the id used by `TimerGroup.timers`.
        let timerID: UUID
        let width: CGFloat

        init(timerID: UUID, width: CGFloat) {
            self.timerID = timerID
            self.width = width
        }
    }

    private(set) var segments: [Segment] = []

    /// The combined width of the rendered label content, which is narrower than the status item
    /// button (macOS adds its own horizontal padding around the label).
    private(set) var contentWidth: CGFloat = 0

    /// Stores the measured segments, scaled so that they exactly fill `contentWidth`.
    ///
    /// Segments are measured one by one while the label is composed, so their sum drifts from the
    /// width of the fully laid out label (kerning, rounding, `ImageRenderer` padding). Normalizing
    /// to the real total keeps the segment boundaries aligned with what is actually on screen.
    func update(segments: [Segment], contentWidth: CGFloat) {
        let measuredWidth = segments.reduce(0) { $0 + $1.width }
        guard measuredWidth > 0, contentWidth > 0 else {
            self.segments = segments
            self.contentWidth = max(contentWidth, 0)
            return
        }
        let scale = contentWidth / measuredWidth
        self.segments = segments.map { Segment(timerID: $0.timerID, width: $0.width * scale) }
        self.contentWidth = contentWidth
    }

    func clear() {
        segments = []
        contentWidth = 0
    }

    /// Turns per-timer content widths into gap-free segments.
    ///
    /// The space between two timers is split evenly between them, so every point of the label
    /// belongs to exactly one timer and there are no dead zones between segments. Any inset before
    /// the first timer belongs to that timer.
    static func distribute(
        ids: [UUID],
        widths: [CGFloat],
        gap: CGFloat,
        leadingInset: CGFloat = 0
    ) -> [Segment] {
        guard ids.count == widths.count, !ids.isEmpty else { return [] }
        let halfGap = gap / 2
        return ids.indices.map { index in
            var width = widths[index]
            if index == 0 { width += leadingInset }
            if index > 0 { width += halfGap }
            if index < ids.count - 1 { width += halfGap }
            return Segment(timerID: ids[index], width: width)
        }
    }

    /// The timer whose segment contains `x`, in the coordinate space of the status item button.
    ///
    /// The label content is assumed to be centered in the button. Clicks outside the content —
    /// the button's edge padding, or anywhere at all when the measurement came out wider than the
    /// button — clamp to the nearest timer, so a right-click on the item is never inert.
    /// Returns `nil` only when there is nothing to hit, i.e. a group with no timers.
    func timerID(atX x: CGFloat, boundsWidth: CGFloat) -> UUID? {
        guard !segments.isEmpty else { return nil }
        guard segments.count > 1 else { return segments[0].timerID }

        let origin = max((boundsWidth - contentWidth) / 2, 0)
        let offset = x - origin

        var edge: CGFloat = 0
        for segment in segments.dropLast() {
            edge += segment.width
            if offset < edge { return segment.timerID }
        }
        return segments[segments.count - 1].timerID
    }
}

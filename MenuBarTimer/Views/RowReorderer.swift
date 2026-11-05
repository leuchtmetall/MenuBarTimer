//
//  RowReorderer.swift
//  MenuBarTimer
//

import AppKit
import Combine
import SwiftUI

/// Drag-to-reorder for a vertical list of equally tall rows, used by the presets list and the group
/// timer editor. The dragged row follows the pointer, the rows it passes slide aside to make room,
/// and Escape cancels the drag. The move is only committed when the drag ends.
///
/// Rows take part by putting a `ReorderHandle` with `gesture(for:in:onMove:)` on them and applying
/// `reorderableRow(_:in:reorderer:)`. Views should call `reset()` when they disappear or leave edit mode.
final class RowReorderer: ObservableObject {
    @Published private(set) var draggedID: UUID?
    @Published private(set) var targetIndex: Int?
    @Published private var startIndex: Int?
    @Published private var dragOffset: CGFloat = 0
    private var isCancelled = false
    private var escapeMonitor: Any?

    /// The distance between the tops of two consecutive rows: row height plus spacing.
    let rowStride: CGFloat

    /// Virtual key code (`NSEvent.keyCode`) of the Escape key, which cancels a drag.
    private static let escapeKeyCode: UInt16 = 53

    init(rowStride: CGFloat) {
        self.rowStride = rowStride
    }

    /// The drag gesture for the handle of row `id`. `ids` are the reorderable rows in display order;
    /// `onMove` receives the dragged row and the index in `ids` whose place it takes.
    func gesture(
        for id: UUID,
        in ids: [UUID],
        onMove: @escaping (_ id: UUID, _ targetIndex: Int) -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { [self] value in
                guard !isCancelled else { return }
                if draggedID == nil {
                    begin(id, in: ids)
                }

                guard draggedID == id, let startIndex else { return }
                dragOffset = value.translation.height
                let indexOffset = Int((dragOffset / rowStride).rounded())
                targetIndex = min(max(0, startIndex + indexOffset), ids.count - 1)
            }
            .onEnded { [self] _ in
                if !isCancelled, draggedID == id, let targetIndex, ids.indices.contains(targetIndex) {
                    onMove(id, targetIndex)
                }
                reset()
            }
    }

    /// How far a row is shifted while a drag is in progress: the dragged row follows the pointer,
    /// and the rows between its start and target slide one place to make room.
    func offset(for id: UUID, in ids: [UUID]) -> CGFloat {
        guard let draggedID, let startIndex, let targetIndex,
              let rowIndex = ids.firstIndex(of: id) else {
            return 0
        }

        if id == draggedID {
            return dragOffset
        }
        if targetIndex > startIndex, rowIndex > startIndex, rowIndex <= targetIndex {
            return -rowStride
        }
        if targetIndex < startIndex, rowIndex >= targetIndex, rowIndex < startIndex {
            return rowStride
        }
        return 0
    }

    /// Ends any drag without moving anything and gets ready for the next one.
    func reset() {
        clearDragState()
        isCancelled = false
    }

    private func begin(_ id: UUID, in ids: [UUID]) {
        draggedID = id
        startIndex = ids.firstIndex(of: id)
        targetIndex = startIndex
        monitorEscapeKey()
    }

    private func monitorEscapeKey() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escapeKeyCode else { return event }
            DispatchQueue.main.async {
                self?.cancel()
            }
            return nil
        }
    }

    /// Stops the drag; the gesture keeps running until the mouse is released, but is ignored.
    private func cancel() {
        clearDragState()
        isCancelled = true
    }

    private func clearDragState() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        draggedID = nil
        startIndex = nil
        targetIndex = nil
        dragOffset = 0
    }
}

/// The grip a reorderable row is dragged by. The caller attaches `RowReorderer.gesture(for:in:onMove:)`.
struct ReorderHandle: View {
    let help: String

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 24)
            .contentShape(Rectangle())
            .help(help)
    }
}

extension View {
    /// Moves and highlights a row while `reorderer` drags it or the rows around it.
    func reorderableRow(_ id: UUID, in ids: [UUID], reorderer: RowReorderer) -> some View {
        let isDragged = reorderer.draggedID == id
        return offset(y: reorderer.offset(for: id, in: ids))
            .opacity(isDragged ? 0.65 : 1)
            .zIndex(isDragged ? 1 : 0)
            .animation(isDragged ? nil : .easeOut(duration: 0.1), value: reorderer.targetIndex)
    }
}

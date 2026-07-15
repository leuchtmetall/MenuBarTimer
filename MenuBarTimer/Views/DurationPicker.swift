//
//  DurationPicker.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

private enum DurationComponent: CaseIterable {
    case hours
    case minutes
    case seconds

    var seconds: Int {
        switch self {
        case .hours: return 3600
        case .minutes: return 60
        case .seconds: return 1
        }
    }

    var maximumValue: Int {
        self == .hours ? 99 : 59
    }

    var previous: DurationComponent {
        switch self {
        case .hours: return .hours
        case .minutes: return .hours
        case .seconds: return .minutes
        }
    }

    var next: DurationComponent {
        switch self {
        case .hours: return .minutes
        case .minutes: return .seconds
        case .seconds: return .seconds
        }
    }
}

private final class DurationTextView: NSView {
    static let maximumDuration = (99 * 3600) + (59 * 60) + 59

    var duration: TimeInterval = 0 {
        didSet {
            if duration != oldValue {
                needsDisplay = true
            }
        }
    }
    var onDurationChange: ((TimeInterval) -> Void)?

    private var selectedComponent = DurationComponent.minutes
    private var pendingDigits = ""
    private let font = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize,
        weight: .regular
    )

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 82, height: 24) }

    override func becomeFirstResponder() -> Bool {
        if let event = NSApp.currentEvent, event.type == .keyDown, event.keyCode == 48 {
            selectedComponent = event.modifierFlags.contains(.shift) ? .seconds : .hours
            pendingDigits = ""
        }
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        pendingDigits = ""
        needsDisplay = true
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        selectedComponent = component(at: point.x)
        pendingDigits = ""
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48:
            pendingDigits = ""
            if event.modifierFlags.contains(.shift) {
                if selectedComponent == .hours {
                    window?.selectPreviousKeyView(self)
                } else {
                    select(selectedComponent.previous)
                }
            } else if selectedComponent == .seconds {
                window?.selectNextKeyView(self)
            } else {
                select(selectedComponent.next)
            }
        case 123:
            select(selectedComponent.previous)
        case 124:
            select(selectedComponent.next)
        case 125:
            adjust(by: -1)
        case 126:
            adjust(by: 1)
        default:
            guard let characters = event.charactersIgnoringModifiers,
                  !characters.isEmpty,
                  characters.allSatisfy(\.isNumber) else {
                return
            }
            insert(characters)
        }
    }

    func adjust(by amount: Int) {
        guard amount != 0 else { return }
        let currentTotal = Int(duration.rounded())
        if amount < 0, componentValue(selectedComponent, in: currentTotal) == 0 {
            return
        }
        let total = currentTotal + (amount * selectedComponent.seconds)
        setDuration(min(Self.maximumDuration, max(0, total)))
        pendingDigits = ""
        needsDisplay = true
    }

    func focusSelectedComponent() {
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let fieldRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let background = NSBezierPath(roundedRect: fieldRect, xRadius: 6, yRadius: 6)
        NSColor.white.setFill()
        background.fill()
        NSColor.separatorColor.setStroke()
        background.lineWidth = 1
        background.stroke()

        let text = formattedDuration
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let textSize = (text as NSString).size(withAttributes: normalAttributes)
        let origin = NSPoint(
            x: bounds.midX - (textSize.width / 2),
            y: bounds.midY - (textSize.height / 2)
        )
        (text as NSString).draw(at: origin, withAttributes: normalAttributes)

        guard window?.firstResponder === self else { return }
        let segment = segmentLayout(for: selectedComponent)
        let selectionRect = NSRect(
            x: origin.x + segment.offset,
            y: origin.y,
            width: segment.width,
            height: textSize.height
        ).insetBy(dx: -1, dy: 0)
        let selection = NSBezierPath(roundedRect: selectionRect, xRadius: 3, yRadius: 3)
        NSColor.selectedTextBackgroundColor.setFill()
        selection.fill()

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.selectedTextColor
        ]
        (segment.text as NSString).draw(
            at: NSPoint(x: origin.x + segment.offset, y: origin.y),
            withAttributes: selectedAttributes
        )
    }

    private var formattedDuration: String {
        let total = min(Self.maximumDuration, max(0, Int(duration.rounded())))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private func select(_ component: DurationComponent) {
        selectedComponent = component
        pendingDigits = ""
        needsDisplay = true
    }

    private func insert(_ characters: String) {
        let candidate = pendingDigits + characters
        guard candidate.count <= 2,
              let value = Int(candidate),
              value <= selectedComponent.maximumValue else {
            pendingDigits = ""
            return
        }

        let total = Int(duration.rounded())
        let currentValue = componentValue(selectedComponent, in: total)
        let updatedTotal = total
            - (currentValue * selectedComponent.seconds)
            + (value * selectedComponent.seconds)
        setDuration(updatedTotal)
        pendingDigits = candidate.count == 2 ? "" : candidate
    }

    private func setDuration(_ total: Int) {
        duration = TimeInterval(min(Self.maximumDuration, max(0, total)))
        onDurationChange?(duration)
    }

    private func componentValue(_ component: DurationComponent, in total: Int) -> Int {
        switch component {
        case .hours: return min(99, max(0, total / 3600))
        case .minutes: return max(0, (total % 3600) / 60)
        case .seconds: return max(0, total % 60)
        }
    }

    private func component(at x: CGFloat) -> DurationComponent {
        let textWidth = (formattedDuration as NSString).size(withAttributes: [.font: font]).width
        let relativeX = x - (bounds.midX - (textWidth / 2))
        let firstSeparatorEnd = ("00:" as NSString).size(withAttributes: [.font: font]).width
        let secondSeparatorEnd = ("00:00:" as NSString).size(withAttributes: [.font: font]).width

        switch relativeX {
        case ..<firstSeparatorEnd: return .hours
        case ..<secondSeparatorEnd: return .minutes
        default: return .seconds
        }
    }

    private func segmentLayout(
        for component: DurationComponent
    ) -> (text: String, offset: CGFloat, width: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        switch component {
        case .hours:
            let text = String(formattedDuration.prefix(2))
            return (text, 0, (text as NSString).size(withAttributes: attributes).width)
        case .minutes:
            let text = String(formattedDuration.dropFirst(3).prefix(2))
            let offset = ("00:" as NSString).size(withAttributes: attributes).width
            return (text, offset, (text as NSString).size(withAttributes: attributes).width)
        case .seconds:
            let text = String(formattedDuration.suffix(2))
            let offset = ("00:00:" as NSString).size(withAttributes: attributes).width
            return (text, offset, (text as NSString).size(withAttributes: attributes).width)
        }
    }
}

/// A duration field with component selection and a matching native stepper.
struct DurationPicker: NSViewRepresentable {
    @Binding var duration: TimeInterval

    func makeCoordinator() -> Coordinator {
        Coordinator(duration: $duration)
    }

    func makeNSView(context: Context) -> NSStackView {
        let textView = DurationTextView()
        textView.duration = duration
        textView.onDurationChange = { newDuration in
            context.coordinator.duration = newDuration
        }
        context.coordinator.textView = textView

        let stepper = NSStepper()
        stepper.minValue = -1
        stepper.maxValue = 1
        stepper.increment = 1
        stepper.integerValue = 0
        stepper.target = context.coordinator
        stepper.action = #selector(Coordinator.stepperChanged(_:))

        let stack = NSStackView(views: [textView, stepper])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2
        return stack
    }

    func updateNSView(_ nsView: NSStackView, context: Context) {
        context.coordinator.textView?.duration = duration
    }

    final class Coordinator: NSObject {
        @Binding var duration: TimeInterval
        fileprivate weak var textView: DurationTextView?

        init(duration: Binding<TimeInterval>) {
            _duration = duration
        }

        @objc func stepperChanged(_ sender: NSStepper) {
            textView?.adjust(by: sender.integerValue)
            sender.integerValue = 0
            textView?.focusSelectedComponent()
        }
    }
}

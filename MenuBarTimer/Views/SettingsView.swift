//
//  SettingsView.swift
//  MenuBarTimer
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Timer groups in the menu bar") {
                    Picker("Timer names", selection: $settings.groupTimerNameDisplay) {
                        ForEach(GroupTimerNameDisplay.allCases) { display in
                            Text(display.title).tag(display)
                        }
                    }
                    // The same setting as the "Compact" button in the timer window.
                    Toggle("Show only the active timer (compact mode)", isOn: $settings.showOnlyActiveGroupTimer)
                    Picker("Other timers in compact mode", selection: $settings.compactInactiveTimerDisplay) {
                        ForEach(CompactInactiveTimerDisplay.allCases) { display in
                            Text(display.title).tag(display)
                        }
                    }
                    .disabled(!settings.showOnlyActiveGroupTimer)
                    .help("Option-click or right-click a timer in the menu bar to switch to it")
                    // "Letter in circle" names are the progress circle.
                    Toggle("Show progress circles", isOn: $settings.showGroupTimerProgress)
                        .disabled(settings.groupTimerNameDisplay == .firstCharacterInCircle)
                        .help(settings.groupTimerNameDisplay == .firstCharacterInCircle
                              ? "The circle around the timer's letter already shows the progress" : "")
                    Toggle("Smaller circles and seconds", isOn: $settings.useCompactColoredLabels)
                        .help("Smaller progress circles, and smaller seconds when hours are shown")
                    Toggle("Use timer colors", isOn: $settings.useGroupTimerColors)
                }

                Section("Timer window") {
                    Toggle("Use timer colors for start buttons of group timers", isOn: $settings.useTimerColorForButtons)
                    Toggle("Show elapsed time below countdown timers", isOn: $settings.showElapsedTimeForCountdowns)
                    Toggle("Keep on top of other windows", isOn: $settings.keepPanelOnTop)
                    Toggle("Swipe right with two fingers to close", isOn: $settings.swipeToDismissPanel)
                }

                Section("Notifications") {
                    Toggle("Notify when a timer finishes", isOn: $settings.showTimerFinishNotification)
                        .onChange(of: settings.showTimerFinishNotification) { _, isEnabled in
                            if isEnabled {
                                TimerCompletionNotifier.requestAuthorization()
                            }
                        }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background(SettingsWindowConfigurator())
    }
}

/// Brings the Settings window to the front and floats it like the main panel, which would otherwise
/// cover it. It uses the hosting view's own window: `NSApp.keyWindow` is often still the main panel
/// (or nil while the app activates) when the Settings window appears.
private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowObservingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowObservingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.level = .floating
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}

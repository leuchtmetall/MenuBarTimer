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
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2.weight(.semibold))
            
            VStack(alignment: .leading, spacing: 10) {
                Picker("Group timer names in menu bar", selection: $settings.groupTimerNameDisplay) {
                    ForEach(GroupTimerNameDisplay.allCases) { display in
                        Text(display.title).tag(display)
                    }
                }
                Toggle("Show progress circle for group timers", isOn: $settings.showGroupTimerProgress)
                    .disabled(!settings.useGroupTimerColors)
                Toggle("Use timer colors in the menu bar", isOn: $settings.useGroupTimerColors)
                Toggle("Compact colored timers", isOn: $settings.useCompactColoredLabels)
                    .disabled(!settings.useGroupTimerColors)
                    .help("Smaller progress circles, and smaller seconds when hours are shown")
                Toggle("Use timer colors for start buttons", isOn: $settings.useTimerColorForButtons)
                Toggle("Show elapsed time below countdown timers", isOn: $settings.showElapsedTimeForCountdowns)
                Toggle("Show a notification when a timer finishes", isOn: $settings.showTimerFinishNotification)
                    .onChange(of: settings.showTimerFinishNotification) { _, isEnabled in
                        if isEnabled {
                            TimerCompletionNotifier.requestAuthorization()
                        }
                    }
                Toggle("Swipe right with two fingers to close the window", isOn: $settings.swipeToDismissPanel)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 370)
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

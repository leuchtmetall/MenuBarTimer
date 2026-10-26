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
                Toggle("Show a notification when a timer finishes", isOn: $settings.showTimerFinishNotification)
                    .onChange(of: settings.showTimerFinishNotification) { _, isEnabled in
                        if isEnabled {
                            TimerCompletionNotifier.requestAuthorization()
                        }
                    }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 370)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate()
                guard let window = NSApp.keyWindow, !(window is MainPanel) else { return }
                // Float like the main panel, which would otherwise cover this window.
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}

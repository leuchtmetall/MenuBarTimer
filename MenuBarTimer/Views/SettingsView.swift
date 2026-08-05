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
                Toggle("Show progress circle for group timers", isOn: $settings.showGroupTimerProgress).disabled(!$settings.useGroupTimerColors.wrappedValue)
                Toggle("Use timer colors in the menu bar", isOn: $settings.useGroupTimerColors)
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
                NSApp.activate(ignoringOtherApps: true)
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}

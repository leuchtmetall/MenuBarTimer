//
//  TimerCompletionNotifier.swift
//  MenuBarTimer
//

import Foundation
import UserNotifications

/// Delivers completion notifications after the user grants macOS notification permission.
enum TimerCompletionNotifier {
    private static let delegate = NotificationDelegate()

    static func configure() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func send(for preset: TimerPreset) {
        let content = UNMutableNotificationContent()
        if let name = preset.name, !name.isEmpty {
            content.title = "\(name) finished"
        } else {
            content.title = "Timer finished"
        }
        content.body = "Your countdown has reached zero."

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            notificationCenter.add(request) { _ in }
        }
    }
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

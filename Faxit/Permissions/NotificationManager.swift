import Foundation
import UserNotifications

/// Local delivery-update notifications. Permission is never requested on
/// launch — only from an in-context prompt (a fax in flight) or the
/// Notifications settings screen, each behind a one-line reason.
enum NotificationManager {
    enum NotificationPermission {
        case notAsked
        case allowed
        case denied
        case provisional
    }

    enum FaxUpdateOutcome {
        case delivered
        case partiallyDelivered
        case notDelivered
    }

    static func permission() async -> NotificationPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notAsked
        case .authorized, .ephemeral: return .allowed
        case .provisional: return .provisional
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    /// Shows the system prompt. Callers record
    /// `settings.hasRequestedNotificationPermission` themselves.
    @discardableResult
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Posts a generic update — lock screens are visible to anyone nearby, so
    /// the text never includes the recipient's number or page contents.
    static func postFaxUpdate(_ outcome: FaxUpdateOutcome, settings: AppSettingsModel) async {
        guard settings.notifyDeliveryUpdates else { return }
        // Read before suspending: the model belongs to the main actor.
        let isQuiet = isInQuietHours(
            enabled: settings.quietHoursEnabled,
            startMinute: settings.quietHoursStartMinute,
            endMinute: settings.quietHoursEndMinute,
            now: .now
        )

        switch await permission() {
        case .allowed, .provisional: break
        case .notAsked, .denied: return
        }

        let content = UNMutableNotificationContent()
        switch outcome {
        case .delivered:
            content.title = CopyDeck.Notifications.deliveredTitle
            content.body = CopyDeck.Notifications.deliveredBody
        case .partiallyDelivered:
            content.title = CopyDeck.Notifications.partiallyDeliveredTitle
            content.body = CopyDeck.Notifications.partiallyDeliveredBody
        case .notDelivered:
            content.title = CopyDeck.Notifications.notDeliveredTitle
            content.body = CopyDeck.Notifications.notDeliveredBody
        }
        if isQuiet {
            content.interruptionLevel = .passive
            content.sound = nil
        } else {
            content.interruptionLevel = .active
            content.sound = .default
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// True when `now` falls inside [start, end) in local time, wrapping past
    /// midnight when start > end (e.g. 22:00–07:00). Equal bounds = never quiet.
    nonisolated static func isInQuietHours(enabled: Bool, startMinute: Int, endMinute: Int, now: Date, calendar: Calendar = .current) -> Bool {
        guard enabled, startMinute != endMinute else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute < endMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }
}

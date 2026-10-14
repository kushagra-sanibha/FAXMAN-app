import Foundation

extension CopyDeck {
    enum Notifications {
        // Notification content — kept generic because lock screens are visible
        // to anyone nearby: no recipient number, no page contents.
        static let deliveredTitle = "Fax delivered"
        static let deliveredBody = "Open Faxit for the delivery report."
        static let partiallyDeliveredTitle = "Fax partly delivered"
        static let partiallyDeliveredBody = "Some pages didn't go through. Open Faxit to resend them."
        static let notDeliveredTitle = "Fax not delivered"
        static let notDeliveredBody = "Open Faxit to see what happened and try again."

        // In-context prompt (FaxStatusDetailView)
        static let promptLine = "Get a notification when this fax is delivered?"
        static let notifyMe = "Notify me"
        static let notNow = "Not now"

        // Settings screen
        static let screenTitle = "Notifications"
        static let permissionHeader = "Permission"
        static let permissionRowTitle = "Notifications"
        static let statusAllowed = "Allowed"
        static let statusProvisional = "Delivered quietly"
        static let statusNotAsked = "Not asked yet"
        static let statusDenied = "Off in iOS Settings"
        static let provisionalNote = "Notifications arrive quietly in Notification Center, without sounds or banners. You can change this in iOS Settings."
        static let turnOnReason = "Faxit only notifies you when a fax you sent is delivered or needs attention."
        static let turnOn = "Turn on notifications"
        static let turnOnFailed = "Notifications weren't turned on. You can turn them on any time in iOS Settings."
        static let deniedExplanation = "Faxit can't alert you about deliveries while notifications are off."
        static let openIOSSettings = "Open iOS Settings"

        static let categoriesHeader = "What Faxit tells you about"
        static let deliveryUpdates = "Delivery updates"
        static let deliveryUpdatesNote = "When a fax you sent is delivered, partly delivered or not delivered. Faxit doesn't send marketing or billing notifications."

        static let quietHoursHeader = "Quiet hours"
        static let quietHours = "Quiet hours"
        static let quietHoursStart = "From"
        static let quietHoursEnd = "Until"
        static let quietHoursNote = "During quiet hours, delivery updates still arrive but without sound or banners."
    }

    enum Access {
        static let screenTitle = "Access"
        static let intro = "These are the only permissions Faxit uses. You can change them any time in iOS Settings."

        static let cameraTitle = "Camera"
        static let cameraReason = "Faxit uses your camera only to scan the pages you choose to fax."
        static let cameraReducedMode = "Without the camera, you can still add pages from Photos or Files."

        static let notificationsTitle = "Notifications"
        static let notificationsReason = "Faxit uses notifications only to tell you when a fax you sent is delivered or needs attention."
        static let notificationsReducedMode = "Without notifications, you can still check every fax's status in Activity."

        static let statusNotRequested = "Not requested yet"
        static let statusAllowed = "Allowed"
        static let statusDenied = "Denied"
        static let statusRestricted = "Restricted by device policy"
        static let statusProvisional = "Delivered quietly"

        static let openSettings = "Open Settings"
        static let restrictedNote = "A device policy (such as Screen Time or a work profile) controls this. Ask whoever manages this iPhone to change it."
    }
}

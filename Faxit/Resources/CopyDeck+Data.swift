import Foundation

extension CopyDeck {
    /// "Export my data" screen and the exported PDF.
    enum ExportData {
        static let title = "Export my data"
        static let intro = "Get a copy of everything Faxit keeps about you, sent to your email as a secure download link. Free on every plan, with your full history."

        static let includedHeader = "What's included"
        static let includedItems = [
            "Fax history: every fax you've sent, with date, recipient, pages, result and price",
            "Received faxes",
            "Drafts",
            "Page images of your sent faxes and drafts",
            "Sender info",
            "Settings",
        ]
        static let formatHeader = "Format"
        static let formatBody = "One PDF file with a summary, your history tables, and every page."

        static let emailHeader = "Where to send it"
        static let emailPlaceholder = "Email address"
        static let emailFieldLabel = "Email address for the export"
        static let emailPrivacyNote = "We use this address only to send this export, then delete it."
        static let invalidEmail = "That doesn't look like an email address. Check it and try again."

        static let sendButton = "Send export"
        static let offlineNote = "Sending an export needs an internet connection. Connect to Wi-Fi or mobile data to continue."

        static let confirmTitle = "Send your export?"
        static func confirmMessage(_ email: String) -> String {
            "Send your data to \(email)? Check it's right — a typo would send your data to a stranger."
        }
        static let confirmAction = "Send"
        static let editAction = "Edit address"

        static let sendingTitle = "Preparing your export…"
        static let sendingBody = "We're putting your PDF together and sending it. This can take a minute if you have a lot of faxes."

        static let sentTitle = "Export sent"
        static func sentBody(linkExpiresAt date: Date) -> String {
            let relative = date.formatted(.relative(presentation: .named))
            let absolute = date.formatted(date: .abbreviated, time: .shortened)
            return "Check your inbox (and spam). The download link expires \(relative) (\(absolute))."
        }
        static let doneAction = "Done"

        static let failedTitle = "Couldn't send your export"
        static let failedBody = "Something went wrong on our side. Your data wasn't sent anywhere. Please try again."
        static let buildFailedBody = "We couldn't put your PDF together. Make sure your iPhone has some free storage, then try again."
        static let offlineFailedBody = "You're offline. Sending an export needs an internet connection — connect and try again."
        static let rateLimitedTitle = "Too many exports"
        static let rateLimitedBody = "You've requested several exports recently. Try again tomorrow."
        static let retryAction = "Try again"
        static let backAction = "Back to Settings"

        // MARK: Exported PDF

        /// Read off the main actor by DataExportBuilder.
        nonisolated enum PDF {
            static func title(appName: String) -> String { "Your \(appName) data" }
            static func generated(_ date: Date) -> String {
                "Generated \(date.formatted(date: .long, time: .shortened))"
            }
            static let summaryHeader = "Summary"
            static let senderHeader = "Sender info"
            static let senderEmpty = "No sender info saved."
            static let senderName = "Name"
            static let senderCompany = "Company"
            static let senderPhone = "Phone"
            static let senderEmail = "Email"
            static let settingsHeader = "Settings"
            static let defaultCoverPage = "Default cover page"
            static let deliveryNotifications = "Delivery notifications"
            static let quietHours = "Quiet hours"
            static let appearance = "Appearance"
            static let appearanceDevice = "Same as device"
            static let appLock = "Lock with Face ID"
            static let ownFaxNumber = "Your fax number"
            static let on = "On"
            static let off = "Off"
            static func quietHoursRange(_ start: String, _ end: String) -> String { "On, \(start) to \(end)" }

            static let sentHeader = "Sent faxes"
            static let sentEmpty = "No sent faxes."
            static let columnDate = "Date"
            static let columnRecipient = "Recipient"
            static let columnPages = "Pages"
            static let columnStatus = "Result"
            static let columnPayment = "Paid with"
            static let columnPrice = "Price"
            static let paymentOneTime = "One-time payment"
            static let paymentPlan = "Plus plan"
            static let priceIncluded = "Included"
            static let priceUnknown = "—"

            static let receivedHeader = "Received faxes"
            static let receivedEmpty = "No received faxes."
            static let columnSender = "From"
            static let unknownSender = "Number not shared"

            static let draftsHeader = "Drafts"
            static let draftsEmpty = "No drafts."
            static let columnLastEdited = "Last edited"
            static let noRecipientYet = "No number yet"

            static let pagesHeader = "Pages"
            static func sentPageCaption(recipient: String, date: String, page: Int, of total: Int) -> String {
                "Sent to \(recipient) on \(date) — page \(page) of \(total)"
            }
            static func draftPageCaption(recipient: String, date: String, page: Int, of total: Int) -> String {
                "Draft to \(recipient), last edited \(date) — page \(page) of \(total)"
            }
            static func receivedPageCaption(sender: String, date: String, page: Int, of total: Int) -> String {
                "Received from \(sender) on \(date) — page \(page) of \(total)"
            }
            static let pageMissing = "This page's image couldn't be found on this iPhone."

            static let statusPreparing = "Preparing"
            static let statusUploading = "Uploading"
            static let statusSending = "Sending"
            static let statusRetrying = "Retrying"
            static func statusPartial(_ delivered: Int, _ total: Int) -> String { "\(delivered) of \(total) pages delivered" }
            static let statusDelivered = "Delivered"
            static let statusNotDelivered = "Not delivered"
            static let statusUnavailable = "Not sent (service unavailable)"
            static let statusCancelled = "Cancelled"
        }
    }

    /// "Delete my data" screen.
    enum DeleteData {
        static let title = "Delete my data"
        static let intro = "This permanently deletes your data from our servers and from this iPhone. It can't be undone."

        static let subscriptionWarningTitle = "You still have an active subscription"
        static let subscriptionWarningBody = "Deleting your data does not cancel it. Apple will keep charging you until you cancel in your Apple subscription settings."

        static let deletedHeader = "What gets deleted"
        static let deletedItems = [
            "Everything stored on our servers under this app's anonymous ID",
            "Sent and received faxes and their pages",
            "Drafts",
            "Delivery reports",
            "Your saved signature",
            "Sender info",
            "Settings",
            "Your fax number assignment in the app",
        ]
        static let keptHeader = "What we keep"
        static let keptBody = "Nothing beyond what the law requires. Apple keeps its own records of your purchases."
        static let timingNote = "Everything on this iPhone is deleted right away. Our servers finish deleting within 30 days."

        static let subscriptionsHeader = "Subscriptions"
        static let subscriptionsNote = "Deleting your data does not cancel App Store subscriptions. Cancel them in Apple's subscription settings."
        static let manageSubscriptions = "Open subscription settings"

        static let deleteButton = "Delete my data"
        static let offlineNote = "Deleting your data from our servers needs an internet connection. Connect to Wi-Fi or mobile data to continue."

        static let confirmTitle = "Delete all your data?"
        static let confirmMessage = "This deletes everything on our servers and on this iPhone, and resets the app. It can't be undone."
        static let confirmAction = "Delete"

        static let deletingTitle = "Deleting your data…"

        static let failedTitle = "Couldn't delete your data"
        static let failedBody = "We couldn't reach our servers to delete your data, so nothing has been deleted — your faxes and settings on this iPhone are untouched. Please try again."
        static let offlineFailedBody = "You're offline, so nothing has been deleted — your faxes and settings on this iPhone are untouched. Connect to the internet and try again."
        static let retryAction = "Try again"

        static let completedTitle = "Your data has been deleted"
        static func completedBody(completesBy date: Date) -> String {
            "Everything on this iPhone is gone. Our servers will finish deleting by \(date.formatted(date: .long, time: .omitted))."
        }
        static let doneAction = "Done"
    }
}

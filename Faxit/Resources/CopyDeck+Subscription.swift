import Foundation
import StoreKit

extension CopyDeck {
    /// Paywall, subscription management, cancellation and restore copy.
    /// Prices and periods always come from StoreKit — nothing here holds a price.
    enum Subscription {
        // MARK: Paywall

        static let upgradeTitle = "Plus plan"
        static let headline = "Send faxes on a simple plan"
        static let subheadline = "Choose weekly, monthly or yearly. Each plan includes a set number of pages."
        static let benefits = [
            "A page allowance every week, month or year — the bigger the plan, the less each page costs",
            "Cover pages are free, and a fax that can't be delivered gives its pages back",
            "Cancel anytime in your Apple ID settings",
        ]
        static let choosePlan = "Choose a plan"
        static let loadingPlanTitle = "Send plan"
        static let loadingPlanPrice = "Loading price"
        static let pricesUnavailableTitle = "We couldn't load the plans"
        static let pricesUnavailableMessage = "The App Store didn't send us the prices. Check your connection and try again."
        static let retry = "Try again"
        static let subscribe = "Subscribe"
        static func subscribeFor(price: String, period: String) -> String {
            "Subscribe for \(price)/\(period)"
        }
        static func renewalTerms(price: String, period: String) -> String {
            "Renews automatically at \(price)/\(period) until you cancel. Cancel anytime in your Apple ID settings at least 24 hours before renewal."
        }
        static let offlineBanner = "You're offline. Subscribing and restoring need an internet connection."
        static let pendingTitle = "Waiting for approval"
        static let pendingMessage = "Someone who manages purchases for this Apple ID needs to approve it. The Plus plan starts as soon as they do. You don't need to keep this screen open."
        static let purchaseFailedTitle = "The purchase didn't go through"
        static let purchaseFailedMessage = "You haven't been charged. Check your connection and try again."
        static let receiveHeader = "Receive faxes"
        static let receivePlanName = "Fax number"
        static let receiveDescription = "Your own number for receiving faxes right in the app. A separate subscription, billed on its own."
        static let receiveAction = "Get a fax number"
        static let receiveActive = "Active"
        static func receiveActiveWithNumber(_ number: String) -> String { "Active · \(number)" }
        static let goToReceive = "Go to Receive"
        static let termsOfUse = "Terms of Use"
        static let privacyPolicy = "Privacy Policy"
        static let close = "Close"

        // MARK: Already subscribed

        static let subscribedTitle = "You're on the Plus plan"
        static let manageSubscription = "Manage subscription"
        static let checkingSubscription = "Checking your subscription…"

        // MARK: Manage subscription

        static let manageTitle = "Subscriptions"
        static let loadingSubscriptions = "Checking your subscriptions…"
        static let emptyTitle = "No subscriptions"
        static let emptyMessage = "You don't have any subscriptions with Faxit on this Apple ID. Sending faxes needs a weekly, monthly or yearly plan."
        static let seeSendPlan = "See the Plus plan"
        static let offlineMessage = "Checking your subscriptions needs an internet connection. Connect and try again."
        static let offlineBannerManage = "You're offline. What you see may be out of date."
        static let loadFailedTitle = "We couldn't check your subscriptions"
        static let loadFailedMessage = "The App Store didn't answer. Check your connection and try again."
        static let openAppleSettings = "Open Apple subscription settings"
        static let appleSettingsFootnote = "Apple handles billing, renewals and refunds for subscriptions."
        static let cancelSubscription = "Cancel subscription"
        static let updatePayment = "Update payment details"
        static let turnRenewalBackOn = "Turn renewal back on"
        static let subscribeAgain = "Subscribe again"

        static func renewsOn(_ date: String) -> String { "Active · Renews on \(date)" }
        static let activeNoDate = "Active"
        static func endsOn(_ date: String) -> String { "Ends on \(date)" }
        static let endsNoDate = "Ends at the end of the current period"
        static func gracePeriod(_ date: String) -> String {
            "Apple couldn't charge your payment method. You keep access until \(date). Update your payment details in Apple settings."
        }
        static let gracePeriodNoDate = "Apple couldn't charge your payment method. You keep access for now. Update your payment details in Apple settings."
        static let billingRetry = "Paused: Apple couldn't charge your payment method, so access is paused. Update your payment details in Apple settings to pick up where you left off."
        static func expiredOn(_ date: String) -> String { "Ended on \(date)" }
        static let expiredNoDate = "Ended"
        static let revoked = "Ended: this purchase was refunded or removed by Apple"

        // MARK: Cancellation flow

        static let cancelFlowTitle = "Cancel subscription"
        static let stepOneTitle = "What changes if you cancel"
        static let sendPlanLoss = "Your page allowance for sending faxes. After the plan ends, you'll need a plan again to send."
        static func numberLoss(_ number: String?) -> String {
            if let number { return "Your fax number \(number), and any faxes sent to it after the plan ends." }
            return "Your fax number, and any faxes sent to it after the plan ends."
        }
        static let keepsData = "Faxes you've already sent and received stay on this iPhone."
        static func accessUntil(_ date: String) -> String {
            "You keep everything until \(date), and you won't be charged again."
        }
        static let accessUntilNoDate = "You keep everything until the end of the period you've paid for, and you won't be charged again."
        static let continueAction = "Continue"
        static let keepSubscription = "Keep subscription"
        static let stepTwoTitle = "Do you still want to cancel?"
        static let stepTwoMessage = "Apple handles cancellations. We'll open your Apple subscription settings, where you can cancel."
        static let continueToCancel = "Continue to cancel"
        static let stepTwoOffline = "Opening Apple's subscription settings needs an internet connection. Connect and try again."
        static let stepThreeTitle = "Finish in Apple's settings"
        static let stepThreeMessage = "Choose Cancel Subscription in Apple's settings. When you're done, come back here and we'll confirm what happens next."
        static let checkingResult = "Checking with Apple…"
        static func endsConfirmation(plan: String, date: String) -> String {
            "Your \(plan) ends on \(date). You keep access until then."
        }
        static func endsConfirmationNoDate(plan: String) -> String {
            "Your \(plan) is cancelled. You keep access until the end of the period you've paid for."
        }
        static func stillRenewing(plan: String, date: String) -> String {
            "Your \(plan) is still active and renews on \(date)."
        }
        static func stillRenewingNoDate(plan: String) -> String {
            "Your \(plan) is still active and will renew."
        }
        static let resultUnknown = "We couldn't check your subscription just now. Your Apple subscription settings always show the latest."
        static let done = "Done"

        // MARK: Restore

        static let restorePurchases = "Restore purchases"
        static let restoredTitle = "Purchases restored"
        static func restoredMessage(_ names: [String]) -> String {
            "Restored: \(ListFormatter.localizedString(byJoining: names))."
        }
        static let nothingFoundTitle = "Nothing to restore"
        static let nothingFoundMessage = "We didn't find a purchase on this Apple ID. Check you're signed in with the one you used."
        static let restoreFailedTitle = "Couldn't restore purchases"
        static let restoreFailedMessage = "We couldn't reach the App Store. Check your connection and try again."
        static let restoreOfflineTitle = "You're offline"
        static let restoreOfflineMessage = "Restoring purchases needs an internet connection. Connect and try again."
        static let ok = "OK"
        static let cancel = "Cancel"

        // MARK: Periods

        /// "month", "year", "3 months" — used as "$4.99/month".
        nonisolated static func periodText(_ period: Product.SubscriptionPeriod) -> String {
            let unit: (singular: String, plural: String)
            switch period.unit {
            case .day: unit = ("day", "days")
            case .week: unit = ("week", "weeks")
            case .month: unit = ("month", "months")
            case .year: unit = ("year", "years")
            @unknown default: unit = ("period", "periods")
            }
            return period.value == 1 ? unit.singular : "\(period.value) \(unit.plural)"
        }

        nonisolated static func dateText(_ date: Date) -> String {
            date.formatted(date: .long, time: .omitted)
        }
    }
}

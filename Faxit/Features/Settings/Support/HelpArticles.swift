import Foundation

/// Help content is bundled in the app as Swift data, so Help works fully
/// offline and never needs a loading state.
struct HelpArticle: Identifiable, Hashable {
    let id: String
    let title: String
    let paragraphs: [String]
    /// Shows a button opening Apple's subscription settings.
    var showsManageSubscriptions = false
}

struct HelpSection: Identifiable {
    let id: String
    let title: String
    let articles: [HelpArticle]
}

enum HelpArticles {
    static let sections: [HelpSection] = [gettingStarted, billing, yourData, troubleshooting]

    // MARK: Billing and cancelling (first article is always cancellation)

    static let billing = HelpSection(id: "billing", title: "Billing and cancelling", articles: [
        HelpArticle(
            id: "cancel",
            title: "How to cancel your subscription",
            paragraphs: [
                "Subscriptions are billed by Apple, so you cancel them in your Apple subscription settings. Tap the button below to open them right here.",
                "Or open the Settings app, tap your name, then Subscriptions, choose Faxit, and tap Cancel Subscription.",
                "After you cancel, the subscription keeps working until the end of the period you've already paid for. It won't renew after that.",
                "The send plan and the fax number are separate subscriptions. Cancel each one you no longer want.",
                "Deleting the app or deleting your data does not cancel a subscription — only Apple's subscription settings do."
            ],
            showsManageSubscriptions: true
        ),
        HelpArticle(
            id: "pricing",
            title: "How pricing works",
            paragraphs: [
                "To send faxes, choose a plan: weekly, monthly or yearly. There's no charge per fax.",
                "Each plan includes a number of pages for each billing period: \(ListFormatter.localizedString(byJoining: FaxPricing.SendPlan.allCases.map(CopyDeck.SendPlan.allowance))). Unused pages don't carry over.",
                "The cover page is free and doesn't use your pages.",
                "If a fax can't be delivered, its pages are given back, and retrying that same fax uses no more pages.",
                "Need more pages before your plan resets? Switch to a bigger plan when you send. It starts right away with its full allowance.",
                "There are no free trials. Every price is shown by Apple before you confirm."
            ]
        ),
        HelpArticle(
            id: "number-billing",
            title: "Paying for a fax number",
            paragraphs: [
                "A fax number for receiving faxes is its own monthly subscription, billed separately from sending.",
                "Having a send plan doesn't include a number, and having a number doesn't include sending. You can cancel either one on its own."
            ]
        ),
        HelpArticle(
            id: "refunds",
            title: "Getting a refund",
            paragraphs: [
                "Apple handles refunds for App Store purchases — request one from your Apple ID purchase history.",
                "We can't issue refunds ourselves, because payments go through Apple, not us.",
                "A refund doesn't cancel a subscription. To stop future charges, cancel it in your subscription settings too."
            ]
        ),
        HelpArticle(
            id: "restore",
            title: "Restoring purchases",
            paragraphs: [
                "There's no account to sign in to. Your subscriptions belong to your Apple ID.",
                "On a new iPhone, or after reinstalling, open Settings in Faxit and tap Restore Purchases while signed in to the same Apple ID.",
                "Active subscriptions come back. Single-fax payments are used up when the fax is sent, so they don't restore."
            ]
        )
    ])

    // MARK: Your data

    static let yourData = HelpSection(id: "data", title: "Your data", articles: [
        HelpArticle(
            id: "where-data",
            title: "Where your faxes are stored",
            paragraphs: [
                "Your sent faxes, drafts, received faxes, sender details, saved signature and settings are stored on this iPhone.",
                "Pages are sent to our fax provider only to deliver them, and removed afterward.",
                "There's no account and no sign-up."
            ]
        ),
        HelpArticle(
            id: "new-phone",
            title: "Moving to a new iPhone",
            paragraphs: [
                "Your fax history does not move to a new iPhone. It's stored only on this device, and turning iCloud on or off makes no difference.",
                "Your purchases do come back: on the new iPhone, tap Restore Purchases in Settings using the same Apple ID. No account needed.",
                "If you want a copy of your faxes, use Export my data in Settings before you switch."
            ]
        ),
        HelpArticle(
            id: "export",
            title: "Exporting your data",
            paragraphs: [
                "Go to Settings and tap Export my data. Enter your email address and we'll email you a link to download your data.",
                "The link expires after a while, so download it soon. If it expires, you can request a new one.",
                "This is the only place Faxit asks for your email, and it's used only to send the link."
            ]
        ),
        HelpArticle(
            id: "delete",
            title: "Deleting your data",
            paragraphs: [
                "Go to Settings and tap Delete my data. This removes your faxes, drafts, received faxes, sender details, signature and settings from this iPhone, and asks our fax provider to delete anything related to you.",
                "This can't be undone. Export your data first if you want a copy.",
                "Deleting your data does not cancel your subscriptions. Cancel them in your Apple subscription settings — see \"How to cancel your subscription\"."
            ]
        )
    ])

    // MARK: Getting started

    static let gettingStarted = HelpSection(id: "start", title: "Getting started", articles: [
        HelpArticle(
            id: "send",
            title: "Sending your first fax",
            paragraphs: [
                "Scan your pages with the camera or add a document, enter the fax number, and review before sending.",
                "You'll see the price before you pay. Then follow the fax's progress in Activity."
            ]
        ),
        HelpArticle(
            id: "statuses",
            title: "What the fax statuses mean",
            paragraphs: [
                "Sending: we're dialing the fax line and transferring pages.",
                "Retrying: the line was busy or didn't answer, so we're trying again automatically.",
                "Delivered: their fax line accepted every page. It doesn't tell us whether anyone has read it.",
                "Partly delivered: some pages went through but not all.",
                "Not delivered: we couldn't get through. The fax shows the reason and lets you try again for free."
            ]
        ),
        HelpArticle(
            id: "receive",
            title: "Receiving faxes",
            paragraphs: [
                "To receive faxes, choose a fax number in the Receive tab. A number is its own monthly subscription.",
                "Faxes sent to your number appear in the Receive tab."
            ]
        )
    ])

    // MARK: Troubleshooting

    static let troubleshooting = HelpSection(id: "trouble", title: "Troubleshooting", articles: [
        HelpArticle(
            id: "busy",
            title: "Busy, no answer, or not a fax line",
            paragraphs: [
                "If the line is busy or doesn't answer, Faxit retries automatically a few times.",
                "If it still can't get through, check the number with the person you're faxing. Many offices have a separate number for their fax machine.",
                "\"Not a fax line\" means a person or voicemail answered instead of a fax machine. Ask for their fax number.",
                "Retrying the same fax is free."
            ]
        ),
        HelpArticle(
            id: "partial",
            title: "Only some pages went through",
            paragraphs: [
                "Partly delivered means the line dropped or the receiving machine stopped partway through.",
                "Open the fax in Activity and try again. Retrying the same fax is free."
            ]
        ),
        HelpArticle(
            id: "camera",
            title: "The camera won't open",
            paragraphs: [
                "Faxit needs camera access to scan pages. If you turned it off, open the Settings app, scroll to Faxit, and turn on Camera.",
                "You can also add a document from Files or Photos instead."
            ]
        ),
        HelpArticle(
            id: "no-incoming",
            title: "Faxes to my number aren't arriving",
            paragraphs: [
                "Make sure your fax number subscription is active — check Manage subscription in Settings, or tap Restore Purchases there.",
                "Check the sender is using the exact number shown at the top of your Inbox, including the area code.",
                "Received faxes download when you're online. If you were offline, open the Inbox tab once you're connected."
            ]
        )
    ])
}

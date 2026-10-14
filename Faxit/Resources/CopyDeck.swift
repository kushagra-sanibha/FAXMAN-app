import Foundation

/// Every user-facing string lives here so copy can be corrected in one place
/// against the real strategy-doc copy deck without hunting through views.
/// App name is "Faxit" (not the strategy doc's placeholder "OneFax").
enum CopyDeck {
    enum App {
        static let name = "Faxit"
    }

    enum Activity {
        static let hero = "FAXMAN"
        static let scanAction = "Scan document"
        static let scanActionSubtitle = "Use your camera to capture pages"
        static let uploadAction = "Upload a file"
        static let uploadActionSubtitle = "Choose a PDF or photo from your iPhone"
        static let orDivider = "OR"
        static let recentFaxesHeader = "Recent faxes"
        static let draftsHeader = "Saved for later"
        static let draftsFooter = "These pages are stored only on this iPhone until you send them."
        static let promoTitle = "Get your own fax number"
        static let promoAction = "Get number"
        static let emptyState = "No faxes yet. Send one below."
        static let sendToHeader = "SEND TO:"
    }

    enum Compose {
        static let title = "Send Fax"
        static let numberFieldPlaceholder = "Fax number"
        static let pasteButton = "Paste number"
        static let addDocumentPrompt = "Add a document"
        static let addDocumentCaption = "Scan pages with your camera, or upload a PDF or photo."
        static let scanButton = "Scan"
        static let chooseFileButton = "Choose file"
        static func pagesAddedSummary(_ count: Int) -> String { "\(count) page\(count == 1 ? "" : "s") added" }
        static let countryNote = "Faxit sends to US and Canada fax numbers."
        static func numberIssueTitle(_ issue: RecipientNumberIssue) -> String {
            switch issue {
            case .empty: "Enter a fax number"
            case .incomplete: "Fax number is incomplete"
            case .tooLong, .invalidAreaCode, .invalidExchange: "Check the fax number"
            }
        }
        static func numberIssueMessage(_ issue: RecipientNumberIssue) -> String {
            switch issue {
            case .empty:
                "Type the recipient's 10-digit fax number, or pick one of your favorites."
            case .incomplete(let missing):
                "Add \(missing) more digit\(missing == 1 ? "" : "s") — US and Canada fax numbers have 10 digits."
            case .tooLong:
                "That's more than 10 digits. Faxit sends to US and Canada numbers only."
            case .invalidAreaCode:
                "That area code isn't valid — it can't start with 0 or 1, or be a service code like 911."
            case .invalidExchange:
                "That number isn't valid — the 3 digits after the area code can't start with 0 or 1, or be a service code like 411."
            }
        }
        static let reviewButton = "Review"
        static let editDocumentPrompt = "Edit your document"
        static let addMoreScan = "Scan more"
        static let addMoreFile = "Add file"
        static let coverPageToggle = "Cover page"
        static let coverPageNote = "Free. Shows who it's from and who it's for."
        static let changeTemplate = "Change template"
        static let retentionDisclosure = "Pages are sent to our fax provider to deliver them, and removed afterward."
        static let cameraDeniedMessage = "Camera is off. Open Settings, or add pages from Photos or Files."
        static let uploadSourceTitle = "Add from"
        static let uploadSourcePhotos = "Photos"
        static let uploadSourceFiles = "Files"
        /// The system Files browser is the only way into iCloud Drive,
        /// Google Drive, Dropbox etc. — separate buttons for each all opened
        /// the same picker, so they were folded into this one honest hint.
        static let uploadSourceFilesHint = "Files includes iCloud Drive, Google Drive, Dropbox and any other storage apps you've connected."
        static let unsupportedFileMessage = "Faxit sends PDFs and photos (JPEG, PNG, HEIC). Convert this file to PDF first."
        static let saveForLaterButton = "Save for later"
        static let saveForLaterConfirmTitle = "Save and finish later?"
        static let saveForLaterConfirmMessage = "Your pages stay on this iPhone — they're never uploaded until you tap send."
        static let saveForLaterConfirmAction = "Save"
    }

    enum Review {
        static let previewCaption = "This is how the page will print on their machine. Zoom in to check the text."
        static let numberFormatValid = "Looks like a US number. We can't tell who it belongs to."
        static let numberFormatInvalid = "That doesn't look like a complete US or Canada number."
        static let darkPageWarning = "This page is very dark. The text may not be readable."
        static let lightPageWarning = "This page looks blank or washed out. The text may not print."
        static let removePage = "Remove page"
        static let brighten = "Brighten"
        static let darken = "Darken"
        static let keepAsIs = "Keep as is"
        static let includedInPlan = "Included in your plan"
        static let purchaseFailedMessage = "We couldn't reach the App Store. Check your connection and try again."
        static let pricingUnavailableMessage = "Pricing isn't available right now. Try again in a moment."
    }

    enum Sending {
        static let title = "Handing off securely"
    }

    enum Status {
        static let preparing = "Getting your fax ready"
        static func sendingTo(_ number: String) -> String { "Sending to \(number)" }
        static func retrying(number: String, attempt: Int, max: Int) -> String {
            "\(number) was busy. Trying again in a few minutes (try \(attempt) of \(max))."
        }
        static func delivered(_ number: String) -> String { "Delivered to \(number)." }
        static let deliveredNote = "Delivered means their fax line accepted every page. It doesn't tell us whether anyone has read it."
        static let downloadReport = "Download delivery report"
        static let failedHeadline = "Your fax couldn't be delivered."
        static func failureReason(_ text: String) -> String { "Reason: \(text)" }
        static let tryAgainSameNumber = "Try the same number again"
        static let checkOrChangeNumber = "Check or change the number"
        static let getHelp = "Get help"
        static let notChargedNote = "Retrying this same fax uses no more pages from your plan."
        static func partiallyDelivered(_ delivered: Int, _ total: Int) -> String {
            "\(delivered) of \(total) pages went through."
        }
        static let providerUnavailable = "We couldn't reach our fax service. Your payment is safe. Try again in a few minutes."
        static let waitingForConnection = "You've paid. We'll send as soon as you're back online."
    }

    enum Inbox {
        static let header = "Received safely"
        static let statPillSuffix = "faxes this month"
        static let searchPlaceholder = "Search by sender or date"
        static let exportButton = "Export"
        static let listHeader = "RECEIVED"
        static let viewAction = "View"
        static let privacyNote = "Stored on this device until you export it."
        static let noNumberCTA = "Get your own fax number"
        static let emptyState = "No faxes received yet."
    }

    enum Settings {
        static let title = "Settings"
        static let faxingSection = "Faxing"
        static let senderInformation = "Sender information"
        static let defaultCoverPage = "Default cover page"
        static let defaultCoverPageCaption = "Select a default cover page template. You can change this anytime when creating a fax."
        static let paperSize = "Fax paper size"
        static let subscriptionSection = "Subscription"
        static let upgrade = "Upgrade to the Plus plan"
        static let manageSubscription = "Manage subscription"
        static let preferencesSection = "Preferences"
        static let notifications = "Notifications"
        static let access = "Access"
        static let appearance = "Appearance"
        static let appLock = "Lock with Face ID"
        static let yourDataSection = "Your data"
        static let exportMyData = "Export my data"
        static let supportSection = "Support"
        static let help = "Help"
        static let contactUs = "Contact us"
        static let feedback = "Send feedback"
        static let aboutSection = "About"
        static let rateOnAppStore = "Rate on the App Store"
        static let shareApp = "Share the app"
        static let privacyPolicy = "Privacy policy"
        static let termsOfUse = "Terms of use"
        static let appInfo = "App info"
        static let deleteMyData = "Delete my data"
        static let saveChanges = "Save changes"
    }

    enum Billing {
        static let loadingPrices = "Loading prices…"
        static let pricesUnavailable = "Prices aren't available right now."
    }
}

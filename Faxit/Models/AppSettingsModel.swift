import Foundation
import SwiftData

/// Light or Dark only — no "System" option (Common Screens Spec). Until
/// the user picks, the app follows the device and records that on first launch.
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// Singleton row holding every app-wide preference. One instance ever exists;
/// `AppSettingsStore` is responsible for fetching-or-creating it.
@Model
final class AppSettingsModel {
    /// Empty until the first launch records the device's appearance.
    /// Older stores may hold "system", which is treated the same way.
    var appearanceModeRaw: String
    var defaultCoverPageRaw: String
    /// Page size every transmitted page is fitted onto. Defaulted so
    /// existing stores migrate; US Letter because Faxit sends to US/Canada.
    var faxPaperSizeRaw: String = "letter"

    var notifyDeliveryUpdates: Bool
    var hasRequestedNotificationPermission: Bool

    /// During quiet hours, delivery notifications arrive silently.
    /// Minutes after midnight; defaulted so existing stores migrate.
    var quietHoursEnabled: Bool = false
    var quietHoursStartMinute: Int = 22 * 60
    var quietHoursEndMinute: Int = 7 * 60

    var pinLockEnabled: Bool

    /// Non-nil once the user has an active rented number (independent of any send plan).
    var ownFaxNumber: String?

    var deliveredFaxCountForRatingPrompt: Int
    var hasRequestedReview: Bool

    /// Set once the first fax is delivered and the Receive tip has been
    /// shown — that moment only happens once. Defaulted so existing stores
    /// migrate without a schema bump.
    var hasShownFirstDeliveryReceiveTip: Bool = false

    init() {
        self.appearanceModeRaw = ""
        self.defaultCoverPageRaw = CoverPageStyle.none.rawValue
        self.notifyDeliveryUpdates = true
        self.hasRequestedNotificationPermission = false
        self.pinLockEnabled = false
        self.ownFaxNumber = nil
        self.deliveredFaxCountForRatingPrompt = 0
        self.hasRequestedReview = false
    }

    /// nil until chosen (or recorded from the device on first launch).
    var appearanceMode: AppearanceMode? {
        get { AppearanceMode(rawValue: appearanceModeRaw) }
        set { appearanceModeRaw = newValue?.rawValue ?? "" }
    }

    var defaultCoverPage: CoverPageStyle {
        get { CoverPageStyle(rawValue: defaultCoverPageRaw) ?? .none }
        set { defaultCoverPageRaw = newValue.rawValue }
    }

    var faxPaperSize: FaxPaperSize {
        get { FaxPaperSize(rawValue: faxPaperSizeRaw) ?? .letter }
        set { faxPaperSizeRaw = newValue.rawValue }
    }
}

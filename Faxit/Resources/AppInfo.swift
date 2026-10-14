import Foundation

/// Per-app variables from the Sanibha Common Screens Spec. Settings rows
/// that depend on a value left `nil` here are hidden — the spec forbids
/// dead or "coming soon" rows — and appear once it's filled in.
enum AppInfo {
    static let appName = "Faxit"
    /// Monitored inbox; must match App Store Connect.
    static let supportEmail = "support@faxit.app"

    /// Numeric App Store ID. Enables "Rate on the App Store" and "Share the app".
    static let appStoreID: String? = nil
    /// Founder-approved share message. "Share the app" needs this and `appStoreID`.
    static let shareMessage: String? = nil
    static let privacyPolicyURL: URL? = nil
    static let termsOfUseURL: URL? = nil
    static let websiteURL: URL? = nil
    /// Must match App Store Connect. Also used for the copyright line.
    static let companyName: String? = nil
    static let companyCity: String? = nil

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    /// "Version 1.0 (12)" — what support asks for.
    static var versionAndBuild: String { "Version \(version) (\(build))" }

    static var appStoreURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }

    static var writeReviewURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }

    static var supportEmailURL: URL? { URL(string: "mailto:\(supportEmail)") }

    /// Apple's own subscription management page — the app can't cancel for the user.
    static let appleSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}

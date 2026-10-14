import Foundation

extension CopyDeck {
    enum About {
        static let title = "About"
        static let appSection = "App"
        static let company = "Company"
        static let location = "Location"
        static let website = "Website"
        static let support = "Support email"
        static let legalSection = "Legal"
        static let licenses = "Licenses"
        static let privacyPolicy = "Privacy policy"
        static let termsOfUse = "Terms of use"
        static func copyright(year: Int, company: String) -> String { "© \(year) \(company)" }
        static let copyVersionHint = "Touch and hold to copy"

        static let offlineTitle = "You're offline"
        static let offlineMessage = "This page needs a connection. Try again when you're online."
        static let retry = "Try again"
        static let done = "Done"

        static let licensesTitle = "Licenses"
        static let noThirdPartyCode = "Faxit doesn't include any third-party code. It's built only with Apple's frameworks."
    }
}

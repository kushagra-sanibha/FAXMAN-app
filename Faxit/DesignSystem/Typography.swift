import SwiftUI
import UIKit
import CoreText

/// Roboto for the whole app (Regular, Medium, Bold — Roboto has no
/// SemiBold, so semibold weights use Bold). Every token scales with Dynamic
/// Type via `relativeTo:`, so text still follows the user's reading size.
///
/// SwiftUI's `.weight(_:)` does nothing on a static custom font, so weighted
/// variants are separate tokens (`faxitBodySemibold`, …) instead.
enum FaxitFont {
    enum Weight {
        case regular, medium, bold, italic

        nonisolated var postScriptName: String {
            switch self {
            case .regular: "Roboto-Regular"
            case .medium: "Roboto-Medium"
            case .bold: "Roboto-Bold"
            case .italic: "Roboto-Italic"
            }
        }

        /// Maps SwiftUI weights onto the three bundled faces.
        init(_ weight: Font.Weight) {
            switch weight {
            case .ultraLight, .thin, .light, .regular: self = .regular
            case .medium: self = .medium
            default: self = .bold
            }
        }
    }

    /// Registers the bundled fonts. Needs no Info.plist entry; call once at launch.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("Roboto") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// A UIFont for drawn output (PDFs, cover pages). Falls back to the system font.
    nonisolated static func ui(size: CGFloat, weight: Weight = .regular) -> UIFont {
        if let font = UIFont(name: weight.postScriptName, size: size) { return font }
        switch weight {
        case .bold: return .systemFont(ofSize: size, weight: .bold)
        case .medium: return .systemFont(ofSize: size, weight: .medium)
        case .regular, .italic: return .systemFont(ofSize: size)
        }
    }
}

extension Font {
    /// Scales with Dynamic Type relative to `style`.
    static func faxit(_ size: CGFloat, _ weight: FaxitFont.Weight = .regular, relativeTo style: Font.TextStyle) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    /// Fixed size, for artwork that must not grow (thumbnails, wheel pickers).
    static func faxit(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(FaxitFont.Weight(weight).postScriptName, fixedSize: size)
    }

    // Sizes match the iOS text styles they stand in for.
    static let faxitHero = faxit(34, .bold, relativeTo: .largeTitle)
    static let faxitLargeTitle = faxitHero
    static let faxitTitle2 = faxit(22, .regular, relativeTo: .title2)
    static let faxitTitle2Bold = faxit(22, .bold, relativeTo: .title2)
    static let faxitTitle3 = faxit(20, .regular, relativeTo: .title3)
    static let faxitSectionHeader = faxit(17, .bold, relativeTo: .headline)
    static let faxitBody = faxit(17, .regular, relativeTo: .body)
    static let faxitBodyMedium = faxit(17, .medium, relativeTo: .body)
    static let faxitBodySemibold = faxit(17, .bold, relativeTo: .body)
    static let faxitBodyBold = faxit(17, .bold, relativeTo: .body)
    static let faxitCaption = faxit(12, .regular, relativeTo: .caption)
    static let faxitCaptionSemibold = faxit(12, .bold, relativeTo: .caption)
    static let faxitCaptionBold = faxit(12, .bold, relativeTo: .caption)
    static let faxitCaption2 = faxit(11, .regular, relativeTo: .caption2)
    static let faxitPrice = faxit(22, .bold, relativeTo: .title2)
}

/// Applied once at the root: Roboto becomes the default for any text that
/// doesn't set its own font, and the system bars (navigation titles, tab
/// labels) are switched to Roboto too.
struct FaxitTypography: ViewModifier {
    init() {
        FaxitFont.register()
        Self.styleSystemBars()
    }

    func body(content: Content) -> some View {
        content.font(.faxitBody)
    }

    private static func styleSystemBars() {
        let titleFont = FaxitFont.ui(size: 17, weight: .bold)
        let largeTitleFont = FaxitFont.ui(size: 34, weight: .bold)
        let navigation = UINavigationBar.appearance()
        navigation.titleTextAttributes = [.font: titleFont]
        navigation.largeTitleTextAttributes = [.font: largeTitleFont]

        let tabItem = UITabBarItem.appearance()
        tabItem.setTitleTextAttributes([.font: FaxitFont.ui(size: 10, weight: .medium)], for: .normal)
        tabItem.setTitleTextAttributes([.font: FaxitFont.ui(size: 10, weight: .medium)], for: .selected)

        UIBarButtonItem.appearance().setTitleTextAttributes([.font: FaxitFont.ui(size: 17)], for: .normal)
    }
}

extension View {
    func faxitTypography() -> some View {
        modifier(FaxitTypography())
    }
}

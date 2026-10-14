import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Colors are defined directly in code as light/dark dynamic providers
/// (rather than an Asset Catalog) so they respond correctly to the single,
/// unified Appearance setting that governs the whole app consistently —
/// no screen is ever hardcoded to one appearance.
private func dynamicColor(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
    #if canImport(UIKit)
    Color(UIColor { traits in
        let (r, g, b) = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    })
    #else
    Color(red: light.0, green: light.1, blue: light.2)
    #endif
}

extension Color {
    // Brand palette: light-to-dark blue (pale powder blue through midnight
    // navy), matching the reference color scheme. Status colors below are
    // semantic (success/warning/error) and intentionally kept separate from
    // the brand palette so their meaning never shifts with branding.
    static let faxitAccent = dynamicColor(light: (0x2B / 255, 0x55 / 255, 0x80 / 255), dark: (0x6F / 255, 0xA8 / 255, 0xD6 / 255))
    static let faxitMintBackground = dynamicColor(light: (0xED / 255, 0xF3 / 255, 0xFA / 255), dark: (0x0B / 255, 0x18 / 255, 0x26 / 255))
    /// Fixed dark navy used for the promo card in both appearances — intentionally always dark, not an adaptive surface.
    static let faxitNavyBackground = dynamicColor(light: (0x1B / 255, 0x3A / 255, 0x5C / 255), dark: (0x1B / 255, 0x3A / 255, 0x5C / 255))
    static let faxitInkPrimary = dynamicColor(light: (0x0E / 255, 0x1C / 255, 0x2A / 255), dark: (0xF0 / 255, 0xF4 / 255, 0xF9 / 255))
    static let faxitInkSecondary = dynamicColor(light: (0x56 / 255, 0x68 / 255, 0x7A / 255), dark: (0xA7 / 255, 0xB4 / 255, 0xC2 / 255))
    static let faxitStatusGreen = dynamicColor(light: (0x1E / 255, 0x8E / 255, 0x5A / 255), dark: (0x34 / 255, 0xC7 / 255, 0x77 / 255))
    static let faxitStatusAmber = dynamicColor(light: (0xC9 / 255, 0x8A / 255, 0x1A / 255), dark: (0xE0 / 255, 0xA5 / 255, 0x3D / 255))
    static let faxitStatusRed = dynamicColor(light: (0xC8 / 255, 0x4B / 255, 0x3D / 255), dark: (0xE2 / 255, 0x63 / 255, 0x5A / 255))
    static let faxitCardBackground = dynamicColor(light: (0xFF / 255, 0xFF / 255, 0xFF / 255), dark: (0x14 / 255, 0x24 / 255, 0x33 / 255))
}

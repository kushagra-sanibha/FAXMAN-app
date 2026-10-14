import SwiftUI

extension AppearanceMode {
    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

extension View {
    /// Applies the chosen appearance. Before the user has chosen, the app
    /// follows the device once and records that as the choice.
    func faxitAppearance(_ settingsStore: AppSettingsStore) -> some View {
        modifier(FaxitAppearanceModifier(settingsStore: settingsStore))
    }
}

private struct FaxitAppearanceModifier: ViewModifier {
    let settingsStore: AppSettingsStore
    @Environment(\.colorScheme) private var deviceScheme

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(settingsStore.appearanceMode?.colorScheme)
            .onAppear {
                guard settingsStore.appearanceMode == nil else { return }
                settingsStore.appearanceMode = deviceScheme == .dark ? .dark : .light
            }
    }
}
